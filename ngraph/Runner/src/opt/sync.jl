# Model with synchronous "move" nodes
#
# The formulation here is similar to the "Simple" formulation, but now data is allowed
# to move from DRAM to PMEM using synchronous move nodes. Using a move node adds
# execution time based on the relative read and write bandwidths.
#
# This is realized by generating a tensor location set for each op the tensor is live.
#
# We then create a variable that is "active" when a tensor changes location from DRAM
# to PMEM. These variables will add time to the objective function
struct SynchronousTensor
    # Possible locations this tensor can live.
    locations::Vector{TensorLocation}
    graph::MetaDiGraph{Int64, Float64}

    # Vector of indices where this tensor is an input
    ops_using_tensor::Vector{Int64}
end

reference_op(S::SynchronousTensor, op) = S.ops_using_tensor[findlast(x -> x <= op, S.ops_using_tensor)]

mutable struct Synchronous <: ModelType
    dram_limit::Int64
    read_bandwidth::Int64
    write_bandwidth::Int64

    # Metadata to help model creation

    # The names of all tensors in the function
    descriptors::Dict{String, SynchronousTensor}
end

Synchronous(a,b,c) = Synchronous(a,b,c, Dict{String,SynchronousTensor}())

#####
##### Helper Functions
#####

inedges(g, v) = (LightGraphs.SimpleEdge(u, v) for u in inneighbors(g, v))
outedges(g, v) = (LightGraphs.SimpleEdge(v, u) for u in outneighbors(g, v))

function create_model(modeltype::Synchronous, profile_data)

    preprocess!(modeltype, profile_data)

    # Start with an empty model that we will progressively build.
    model = Model(with_optimizer(Gurobi.Optimizer))

    # Create an empty expression that will be progressively generated to the final
    # objective.
    model[:objective_expr] = AffExpr()

    add_tensors!(modeltype, model, profile_data)
    add_nodes!(modeltype, model, profile_data)
    add_constraints!(modeltype, model, profile_data)

    # Add the objective expression we've built up.
    @objective(model, Min, model[:objective_expr])

    return model
end

function preprocess!(S::Synchronous, profile_data)
    for tensor in values(profile_data.tensors)
        name  = tensor.name
        locations = tensor.locations

        cost_table = Dict(
            (DRAM, DRAM) => 0,
            (DRAM, PMEM) => round(Int, tensor.bytes / S.write_bandwidth * 1E6),
            (PMEM, DRAM) => round(Int, tensor.bytes / S.read_bandwidth * 1E6),
            (PMEM, PMEM) => 0,
        )

        # Get the indices of ops that have this tensor as an input
        ops_using_tensor = [
            i
            for i in 1:length(profile_data.nodes)
            if in(name, profile_data.nodes[i].input_tensors)
        ]
        # When tensors are created, they either have to live in DRAM or PMEM.
        #
        # By placing a zero index at the front of this vector, we can get the tensor
        # state right when its allocated.
        pushfirst!(ops_using_tensor, 0)

        # Main idea is that we use a source node with outward flow of 1. It can flow
        # into either PMEM or DRAM. Tensors in PMEM can flow to both PMEM and DRAM at
        # the same time, while tensors in DRAM can only flow to one of PMEM or DRAM.
        #
        # Every time there is a transfer, it incurs some runtime cost.
        g = MetaDiGraph()
        add_vertex!(g, :role, :source)
        add_vertex!(g, :role, :sink)

        # Set the vertex numbers of the source and sink vertices to make adding edges
        # easier
        source_vertex = 1
        sink_vertex = 2

        # Add nodes for each region
        first = true
        last_index = 0
        for index in ops_using_tensor
            for location in locations
                meta = Dict(
                    :role => :intermediate,
                    :index => index,
                    :location => location
                )
                add_vertex!(g, meta)

                # Edge Logic
                if first
                    # Add an edge from the source vertex to the newly created verted
                    # (found by asking the number of vertices in the graph.)
                    #
                    # This edge has a cost of 0 since it just serves as a source.
                    add_edge!(g, source_vertex, nv(g), :cost, 0)
                else
                    # Look for connections to the previous index.
                    for vertex in filter_vertices(g, :index, last_index)
                        other_location = get_prop(g, vertex, :location)
                        add_edge!(g, vertex, nv(g), :cost, cost_table[(other_location, location)])
                    end
                end
            end
            first = false
            last_index = index
        end

        # Add edges to the sink
        for vertex in filter_vertices(g, :index, last_index)
            add_edge!(g, vertex, sink_vertex, :cost, 0)
        end

        # Create the descriptor
        S.descriptors[name] = SynchronousTensor(
            locations,
            g,
            ops_using_tensor,
        )
    end
end

function add_tensors!(S::Synchronous, model, profile_data)
    descriptors = S.descriptors
    names = collect(keys(descriptors))

    # Create variables for the tensors
    @variable(model,
        tensor_graphs[
            name = names,
            e = edges(descriptors[name].graph)
        ],
        Bin
    )

    for name in names
        g = descriptors[name].graph
        # Constrain flow out of the source nodes should be 1
        source_vertex = 1
        @constraint(model,
            sum(tensor_graphs[name, e] for e in outedges(g, source_vertex)) == 1
        )

        # Constrain flow into the sink to be 1
        sink_vertex = 2
        @constraint(model,
            sum(tensor_graphs[name, e] for e in inedges(g, sink_vertex)) == 1
        )

        # For DRAM nodes, flow out is less than or equal to flow in, and flow in must
        # be 1.
        for v in filter_vertices(g, :location, DRAM)
            @constraint(model,
                sum(tensor_graphs[name, e] for e in inedges(g, v)) <= 1
            )

            @constraint(model,
                sum(tensor_graphs[name, e] for e in inedges(g, v))
                >= sum(tensor_graphs[name, e] for e in outedges(g, v))
            )
        end

        # For PMEM nodes, we can copy data from PMEM into DRAM and still keep the
        # data around in PMEM>
        #
        # Thus, the out flow of PMEM nodes can be greater than the in flow
        for v in filter_vertices(g, :location, PMEM)
            @constraint(model,
                sum(tensor_graphs[name, e] for e in inedges(g, v)) <= 1
            )

            @constraint(model,
                sum(tensor_graphs[name, e] for e in inedges(g, v))
                <= sum(tensor_graphs[name, e] for e in outedges(g, v))
            )
        end
    end

    # Add costs for edges
    objective_expr = model[:objective_expr]
    for name in names
        g = descriptors[name].graph
        for e in edges(g)
            # Get the cost for this edge. If it's not zero, add it to the objective.
            if has_prop(g, e, :cost)
                cost = get_prop(g, e, :cost)
                if !iszero(cost)
                    add_to_expression!(objective_expr, cost, tensor_graphs[name, e])
                end
            end
        end
    end

    # Finally, we have to create tensor location variables.
    @variable(model,
        tensor_in_dram[
            name = names,
            op = descriptors[name].ops_using_tensor
        ],
        Bin
    )

    # A tensor in DRAM is live if any of its incoming edges are used.
    for name in names
        g = descriptors[name].graph
        for op in descriptors[name].ops_using_tensor
            # Find the vertex with this index that lives in DRAM.
            filtered = filter_vertices(g, (g,v) -> _filter(g, v, :index => op, :location => DRAM)) |> collect

            @assert length(filtered) == 1
            v = first(filtered)

            # Any incoming edge taken implies tensor is in DRAM
            for e in inedges(g, v)
                @constraint(model, tensor_in_dram[name, op] >= tensor_graphs[name, e])
            end

            # If all incoming edges are not taken, tensor must not be in DRAM.
            @constraint(model,
                tensor_in_dram[name, op]
                <= sum(tensor_graphs[name, e] for e in inedges(g, v))
            )
        end
    end

    return
end

function _filter(g, v, args...)
    for arg in args
        has_prop(g, v, first(arg)) || return false
        get_prop(g, v, first(arg)) == last(arg) || return false
    end
    return true
end

function add_nodes!(S::Synchronous, model, profile_data)
    for (op, node_data) in enumerate(profile_data.nodes)
        # We don't profile all ops, so perform a quick check to see if this is an op
        # the we have profile information for. If not, there's nothing to do as far as the
        # ILP model is concerned.
        keep(node_data.description) || continue

        configs = collect(keys(node_data.timings))

        # Create a variable for each config.
        vars = @variable(model, [config = configs], Bin)

        # Constrain each variable to be active if all of its inputs are active. We refer
        # to the tensors variables created earlier to generate these constraings.
        tensor_in_dram = model[:tensor_in_dram]

        inputs = node_data.input_tensors
        outputs = node_data.output_tensors

        for config in configs
            # Create an expression for the input and output locations
            expr = AffExpr() 
            iter = Iterators.flatten((
                zip(config.inputs, inputs),
                zip(config.outputs, outputs)
            ))

            for (location, name) in iter
                n = reference_op(S.descriptors[name], op)
                if location == DRAM
                    add_to_expression!(expr, tensor_in_dram[name, n])
                else
                    add_to_expression!(expr, 1)
                    add_to_expression!(expr, -1, tensor_in_dram[name, n])
                end
            end

            @constraint(model, vars[config] + length(config.inputs) + length(config.outputs) >= 
                1 + expr)
        end

        # Mutate the "objective_expr" with these timings
        objective_expr = model[:objective_expr]
        for config in configs
            # For now, just use the Mean
            coeff = round(Int64, mean(node_data.timings[config]))
            add_to_expression!(objective_expr, coeff, vars[config])
        end
    end
    return
end

function add_constraints!(S::Synchronous, model, profile_data)
    # Unpack some variables
    dram_limit = S.dram_limit
    tensor_data = profile_data.tensors
    tensor_in_dram = model[:tensor_in_dram]

    # Constrain the live tensors in DRAM to be below a certain threshold.
    for (index, free_tensors) in enumerate(live_tensors(profile_data))
        live_free_tensors = filter(!in(profile_data.fixed_tensors), free_tensors)
        if !isempty(live_free_tensors)
            @constraint(model,
                sum(
                    tensor_data[n].bytes * tensor_in_dram[n, reference_op(S.descriptors[n], index)]
                    for n in live_free_tensors
                ) <= dram_limit
            )
        end
    end

    return
end
