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

@enum VertexLocation  LOC_PMEM LOC_DRAM LOC_PREAD LOC_SOURCE LOC_SINK

# Metadata to assign to each node in the liveness graph for tensors.
struct VertexMetadata
    # The gadget that this vertex belongs to. Used for edge generation.
    gadget::Int
    # The op index that this gadget refers to
    op::Int 
    # Where the vertex lives
    location::VertexLocation
end

struct EdgeMetadata
    cost::Int64
end


_meta(g, x) = get_prop(g, x, :metadata)

function preprocess!(S::Synchronous, profile_data)
    for tensor in values(profile_data.tensors)
        name  = tensor.name
        locations = tensor.locations

        read_cost = round(Int, tensor.bytes / (S.read_bandwidth * 1E6))
        write_cost = round(Int, tensor.bytes / (S.write_bandwidth * 1E6))

        cost_table = Dict(
            # DRAM source
            (LOC_DRAM, LOC_DRAM) => 0,
            (LOC_DRAM, LOC_PREAD) => write_cost + read_cost,
            (LOC_DRAM, LOC_PMEM) => write_cost,

            # PREAD source
            (LOC_PREAD, LOC_PREAD) => read_cost,
            (LOC_PREAD, LOC_PMEM) => 0,

            # PMEM source
            (LOC_PMEM, LOC_DRAM) => read_cost,
            (LOC_PMEM, LOC_PREAD) => read_cost,
            (LOC_PMEM, LOC_PMEM) => 0

            # Source source
            (LOC_SOURCE, LOC_PMEM) => 0,
            (LOC_SOURCE, LOC_DRAM) => 0,

            # sinks
            (LOC_PMEM, LOC_SINK) => 0,
            (LOC_DRAM, LOC_SINK) => 0
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

        g = MetaDiGraph()

        add_vertex!(g, :metadata, VertexMetadata(0, 0, LOC_SOURCE))
        # Add nodes for each region
        for (count, index) in enumerate(ops_using_tensor)
            islast = (index == last(ops_using_tensor))

            # Enumerate over locations that this tensor can live.
            #
            # Do it this way because some nodes can only live in DRAM, so iterating 
            # then filtering takes care of that
            for location in locations
                isfirst = count == 1

                if location == DRAM
                    metadata = VertexMetadata(count, index, LOC_DRAM)
                    add_vertex!(g, :metadata, metadata)
                end

                if location == PMEM
                    metadata = VertexMetadata(count, index, LOC_PMEM)
                    add_vertex!(g, :metadata, metadata)

                    # Add the intermediate node if we're not on the first or last step
                    # of this graph
                    if !isfirst && !islast
                        metadata = VertexMetadata(count, index, LOC_PREAD)
                        add_vertex!(g, :metadata, metadata)
                    end
                end
            end
            if islast
                # Set the gadget number for the sink to one higher than the last count.
                add_vertex!(g, :metadata, VertexMetadata(0, count + 1, LOC_SINK))
            end
        end

        # Use a quadratic complexity algorithm for doing edge assignment. It's not 
        # perfect but it's simple, and as long as the graphs don't get too big should
        # run quickly enough for our purposes.
        for src in vertices(g), dst in vertices(g)

            # Connections between gadgets
            if _meta(g, src).gadget == _meta(g, dst).gadget + 1 
                # Create a tuple of the two locations. If this is a defined key in the
                # cost table, add an edge with the associated cost.
                key = (_meta(g, src).location, _meta(g, dst).location) 
                if haskey(cost_table, key)
                    println(key)
                    add_edge!(g, src, dst, :metadata, EdgeMetadata(cost_table[key]))
                end
            end

        end

        # Create the descriptor
        S.descriptors[name] = SynchronousTensor(locations, g, ops_using_tensor)
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
        # Iterate through nodes in the graph - generating constraints based on the type
        # of node.
        for v in vertices(g)
            # Set flow coming out of the source node
            if _meta(g, v).location == LOC_SOURCE
                @constraint(model,
                    sum(tensor_graphs[name, e] for e in outedges(g, v)) == 1
                )

            # Set flow going into the sink node
            elseif _meta(g, v).location == LOC_SINK
                @constraint(model,
                    sum(tensor_graphs[name, e] for e in inedges(g, v)) == 1
                )

            # All other ops must conserve flow
            else
               @constraint(model,
                   sum(tensor_graphs[name, e] for e in outedges(g, v)) == sum(tensor_graphs[name, e] for e in inedges(g, v))
               )
        end
    end

    # Add costs for edges
    objective_expr = model[:objective_expr]
    for name in names
        g = descriptors[name].graph
        for e in edges(g)
            cost = _meta(g, e).cost
            if !iszero(cost)
                add_to_expression!(objective_expr, cost, tensor_graphs[name, e])
            end
        end
    end

    # Finally, we have to create tensor location variables.
    @variable(model,
        tensor_in_dram[
            name = names,
            op = descriptors[name].ops_using_tensor,
            position = [PRE_OP, POST_OP]
        ],
        Bin
    )

    # A tensor in DRAM is live if any of its incoming edges are used.
    for name in names
        g = descriptors[name].graph

        for v in filter_vertices(g, (g, v) -> _meta(g, v).location == DRAM)
            # Skip source or sink nodes
            role = _meta(g, v).role
            op = _meta(g, v).op

            in(role, (SOURCE, SINK)) && continue

            # Tensors will be live is any incoming edge is taken, and dead if NO 
            # incoming edges are used
            for e in inedges(g, v)
                @constraint(model, tensor_in_dram[name, op, role] >= tensor_graphs[name, e])
            end

            # If all incoming edges are not taken, tensor must not be in DRAM.
            @constraint(model,
                sum(tensor_graphs[name, e] for e in inedges(g, v)) >=
                tensor_in_dram[name, op, role]
            )
             
        end
    end

    return
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
                    add_to_expression!(expr, tensor_in_dram[name, n, PRE_OP])
                else
                    add_to_expression!(expr, 1)
                    add_to_expression!(expr, -1, tensor_in_dram[name, n, PRE_OP])
                end
            end

            @constraint(model, vars[config] + length(config.inputs) + length(config.outputs) >= 
                1 + expr)
        end

        # Mutate the "objective_expr" with these timings
        objective_expr = model[:objective_expr]
        for config in configs
            # For now, just use the Mean
            coeff = round(Int64, minimum(node_data.timings[config]))
            add_to_expression!(objective_expr, coeff, vars[config])
        end
    end
    return
end

pre_or_post(descriptor, index) = (reference_op(descriptor, index) == index) ? PRE_OP : POST_OP

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
                    tensor_data[n].bytes * tensor_in_dram[
                        n, 
                        reference_op(S.descriptors[n], index),
                        pre_or_post(S.descriptors[n], index)]
                    for n in live_free_tensors
                ) <= dram_limit
            )
        end
    end

    return
end
