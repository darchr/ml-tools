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

@enum VertexRole SOURCE SINK PRE_OP POST_OP

# Metadata to assign to each node in the liveness graph for tensors.
struct VertexMetadata
    # The role this vertex plays in the graph
    role::VertexRole
    # The gadget that this vertex belongs to. Used for edge generation.
    gadget::Int
    # The op index that this gadget refers to
    op::Int 
    # Where the vertex lives
    location::TensorLocation
    # Switch for the last node
    islast::Bool 
end

struct EdgeMetadata
    cost::Int64
end


_meta(g, x) = get_prop(g, x, :metadata)

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

        add_vertex!(g, :metadata, VertexMetadata(SOURCE, 0, 0, DRAM, false))
        add_vertex!(g, :metadata, VertexMetadata(SINK, 0, 0, DRAM, true))

        # Add nodes for each region
        for (count, index) in enumerate(ops_using_tensor)
            # Enumerate over locations that this tensor can live.
            #
            # Do it this way because some nodes can only live in DRAM, so iterating 
            # then filtering takes care of that
            for location in locations
                islast = (index == last(ops_using_tensor))

                if location == DRAM
                    # Create two nodes - a pre-op node and a post-op node.
                    pre_op_meta = VertexMetadata(PRE_OP, count, index, location, islast)
                    add_vertex!(g, :metadata, pre_op_meta)

                    # Add a post op node
                    post_op_meta = VertexMetadata(POST_OP, count, index, location, islast)
                    add_vertex!(g, :metadata, post_op_meta)

                elseif location == PMEM
                    # Just add a single node for the PMEM case
                    metadata = VertexMetadata(PRE_OP, count, index, location, islast)
                    add_vertex!(g, :metadata, metadata)
                end
            end
        end
        
        # Use a quadratic complexity algorithm for doing edge assignment. It's not 
        # perfect but it's simple, and as long as the graphs don't get too big should
        # run quickly enough for our purposes.
        for src in vertices(g), dst in vertices(g)
            # Source connections
            if _meta(g, src).role == SOURCE && 
                _meta(g, dst).role == PRE_OP && 
                _meta(g, dst).gadget == 1

                add_edge!(g, src, dst, :metadata, EdgeMetadata(0))
            end

            # Sink Connections
            if _meta(g, src).islast && _meta(g, dst).role == SINK
                add_edge!(g, src, dst, :metadata, EdgeMetadata(0))
            end

            # Connections between gadgets
            if _meta(g, src).gadget == _meta(g, dst).gadget + 1 
                # Connect DRAM pre_op nodes to PMEM nodes.
                if _meta(g, src).location == DRAM && 
                    _meta(g, src).role == PRE_OP &&
                    _meta(g, dst).location == PMEM 

                    add_edge!(g, src, dst, :metadata, EdgeMetadata(cost_table[(DRAM,PMEM)]))
                    println("DRAM -> PMEM")
                end

                # Connect PMEM nodes to DRAM Nodes
                if _meta(g, src).location == PMEM &&
                    _meta(g, dst).location == DRAM &&
                    _meta(g, dst).role == PRE_OP

                    add_edge!(g, src, dst, :metadata, EdgeMetadata(cost_table[(PMEM,DRAM)]))
                    println("PMEM -> DRAM")
                end

                # Connect DRAM post-op and pre-op nodes
                if _meta(g, src).location == DRAM && _meta(g, src).role == POST_OP &&
                    _meta(g, dst).location == DRAM && _meta(g, dst).role == PRE_OP

                    add_edge!(g, src, dst, :metadata, EdgeMetadata(0))
                    println("DRAM POST -> DRAM PRE")
                end

                # Connect PMEM to PMEM nodes
                if _meta(g, src).location == PMEM && _meta(g, dst).location == PMEM 
                    add_edge!(g, src, dst, :metadata, EdgeMetadata(0))
                    println("PMEM -> PMEM")
                end
            end

            # Connect pre-op and post-op DRAM nodes
            if _meta(g, src).gadget == _meta(g, dst).gadget &&
                _meta(g, src).location == DRAM && _meta(g, src).role == PRE_OP &&
                _meta(g, dst).location == DRAM && _meta(g, dst).role == POST_OP

                add_edge!(g, src, dst, :metadata, EdgeMetadata(0))
                println("DRAM PRE -> DRAM POST")
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
            if _meta(g, v).role == SOURCE
                @constraint(model,
                    sum(tensor_graphs[name, e] for e in outedges(g, v)) == 1
                )

            # Set flow going into the sink node
            elseif _meta(g, v).role == SINK
                @constraint(model,
                    sum(tensor_graphs[name, e] for e in inedges(g, v)) == 1
                )

            # Post Op nodes must conserve flow
            elseif _meta(g, v).role == POST_OP
               @constraint(model,
                   sum(tensor_graphs[name, e] for e in outedges(g, v)) == sum(tensor_graphs[name, e] for e in inedges(g, v))
               )

            # Differentiate between PMEM and DRAM nodes
            # Pre-op dram nodes can drop flow
            elseif _meta(g, v).role == PRE_OP && _meta(g, v).location == DRAM 
                # Total flow through the vertex must be 1
                @constraint(model,
                    sum(tensor_graphs[name, e] for e in inedges(g, v)) <= 1
                )

                @constraint(model,
                    sum(tensor_graphs[name, e] for e in inedges(g, v)) >=
                    sum(tensor_graphs[name, e] for e in outedges(g, v))
                )

            # PMEM nodes can generate flow if they want, but the INCOMING flow must
            # be at most 1
            elseif _meta(g, v).role == PRE_OP && _meta(g, v).location == PMEM
                @constraint(model,
                    sum(tensor_graphs[name, e] for e in inedges(g, v)) <= 1
                )

                @constraint(model,
                    sum(tensor_graphs[name, e] for e in inedges(g, v)) <=
                    sum(tensor_graphs[name, e] for e in outedges(g, v))
                )
            else
                error()
            end
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
