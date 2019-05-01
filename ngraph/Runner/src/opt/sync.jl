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
    bytes::Int64
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

limit(S::Synchronous) = S.dram_limit
predict(F::Frame{Synchronous}) = objective_value(F.model)

#####
##### Helper Functions
#####

# Why do these not exist in LightGraphs.jl??
inedges(g, v) = (edgetype(g)(u, v) for u in inneighbors(g, v))
outedges(g, v) = (edgetype(g)(v, u) for u in outneighbors(g, v))

function create_model(modeltype::Synchronous, profile_data)

    preprocess!(modeltype, profile_data)

    # Start with an empty model that we will progressively build.
    model = Model(with_optimizer(Gurobi.Optimizer; TimeLimit = 60, MIPGap = 0.0003))
    frame = Frame(modeltype, model, profile_data)

    # Create an empty expression that will be progressively generated to the final
    # objective.
    model[:objective_expr] = AffExpr()

    add_tensors!(frame)
    add_nodes!(frame)
    add_constraints!(frame)

    # Add the objective expression we've built up.
    @objective(frame.model, Min, frame.model[:objective_expr])

    return frame
end

@enum VertexLocation LOC_PMEM LOC_DRAM LOC_SOURCE LOC_SINK
@enum EdgeType EDGE_READ EDGE_WRITE EDGE_NONE

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
    edgetype::EdgeType
end

_meta(g, x) = get_prop(g, x, :metadata)
droplast(x) = Iterators.take(x, length(x)-1)

function preprocess!(S::Synchronous, profile_data)
    for tensor in values(profile_data.tensors)
        name  = tensor.name
        locations = tensor.locations


        # Get the indices of ops that have this tensor as an input
        ops_using_tensor = [
            i
            for i in 1:length(profile_data.nodes)
            if in(name, profile_data.nodes[i].input_tensors)
        ]
        # When tensors are created, they either have to live in DRAM or PMEM.
        #
        # We insert the op that creates this tensor at the first of the
        # `ops_using_tensor` vector
        pushfirst!(ops_using_tensor, findfirst(x -> in(name, x.output_tensors), profile_data.nodes))

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
                    # Add DRAM node
                    add_vertex!(g, :metadata, VertexMetadata(count, index, LOC_DRAM))
                end

                if location == PMEM
                    # Add pre and post PMEM nodes
                    add_vertex!(g, :metadata, VertexMetadata(count, index, LOC_PMEM))
                end
            end
            if islast
                # Set the gadget number for the sink to one higher than the last count.
                add_vertex!(g, :metadata, VertexMetadata(count + 1, 0, LOC_SINK))
            end
        end

        # Create a dictionary mapping source and destination locations to a function.
        #
        # That function will take the gadget numbers of the source and destination. If
        # there should be an edge, return the appropriate metadata. Otherwise, return 
        # `nothing`.
        metadata_map = Dict(
            (LOC_SOURCE, LOC_DRAM) => (s,d) -> isone(d) ? EdgeMetadata(EDGE_NONE) : nothing,
            (LOC_SOURCE, LOC_PMEM) => (s,d) -> isone(d) ? EdgeMetadata(EDGE_NONE) : nothing,

            # LOC_DRAM as source
            (LOC_DRAM, LOC_DRAM) => (s,d) -> (s == d-1) ? EdgeMetadata(EDGE_NONE) : nothing,
            (LOC_DRAM, LOC_PMEM) => (s,d) -> (s == d-1) ? EdgeMetadata(EDGE_WRITE) : nothing,
            (LOC_DRAM, LOC_SINK) => (s,d) -> (s == d-1) ? EdgeMetadata(EDGE_NONE) : nothing,

            # LOC_PMEM_PRE as the source
            #
            # Don't connect the pre-node to DRAM for the first gadget.
            (LOC_PMEM, LOC_DRAM) => (s,d) -> (s == d) && !isone(s) ? EdgeMetadata(EDGE_READ) : nothing,
            (LOC_PMEM, LOC_PMEM) => (s,d) -> (s == d-1) ? EdgeMetadata(EDGE_NONE) : nothing,
            (LOC_PMEM, LOC_SINK) => (s,d) -> (s == d-1) ? EdgeMetadata(EDGE_NONE) : nothing,
        )

        # Use a quadratic complexity algorithm for doing edge assignment. It's not
        # perfect but it's simple, and as long as the graphs don't get too big should
        # run quickly enough for our purposes.
        for src in vertices(g), dst in vertices(g)
            src == dst && continue

            src_meta = _meta(g, src)
            dst_meta = _meta(g, dst)

            # Create a key from the source and destination pairs
            key = (src_meta.location, dst_meta.location) 

            # Get the metadata function from `metadata_map` and pass the source and 
            # destination gadget numbers to the function.
            #
            # If the result is `nothing`, no edge should be created. Otherwise, create
            # an edge with the given metadata.
            fn = get(metadata_map, key, (args...) -> nothing)
            metadata = fn(src_meta.gadget, dst_meta.gadget)
            isnothing(metadata) && continue

            add_edge!(g, src, dst, :metadata, metadata) 
        end

        # Create the descriptor
        S.descriptors[name] = SynchronousTensor(locations, tensor.bytes, g, ops_using_tensor)
    end
end

function add_tensors!(F::Frame{Synchronous})
    descriptors = F.modeltype.descriptors
    names = collect(keys(descriptors))

    # Create variables for the tensors
    @variable(F.model,
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
                @constraint(F.model,
                    sum(tensor_graphs[name, e] for e in outedges(g, v)) == 1
                )

            # Set flow going into the sink node
            elseif _meta(g, v).location == LOC_SINK
                @constraint(F.model,
                    sum(tensor_graphs[name, e] for e in inedges(g, v)) == 1
                )

            # All other ops must conserve flow
            else
                oe = collect(outedges(g, v))
                ie = collect(inedges(g, v))
               @constraint(F.model,
                   sum(tensor_graphs[name, e] for e in oe) - sum(tensor_graphs[name, e] for e in ie) == 0
               )
           end
        end
    end

    #####
    ##### Add objective penalty for moving data
    #####

    objective_expr = F.model[:objective_expr] 
    read_bandwidth = F.modeltype.read_bandwidth
    write_bandwidth = F.modeltype.write_bandwidth

    # A tensor is written to dram if:
    # - It was not created into PMEM
    # - Any edge from DRAM to PMEM is taken
    #
    # NOTE: We only pay the write cost once.
    @variable(F.model, tensor_write[name = names], Bin)

    # Add objective terms for all read ops
    for name in names
        descriptor = descriptors[name]

        # Skip if this tensor can never be assigned to PMEM
        in(PMEM, descriptor.locations) || continue

        g = descriptor.graph
        bytes = descriptor.bytes
        
        read_cost = round(Int, bytes / read_bandwidth)
        write_cost = round(Int, bytes / write_bandwidth)

        # Objective terms for read ops
        for e in filter_edges(g, (g,e) -> _meta(g, e).edgetype == EDGE_READ)
            add_to_expression!(objective_expr, read_cost, tensor_graphs[name, e])
        end

        # objbetive terns for write ops
        first_pmem_edge = find_edge(g,
            (g,e) -> 
                _meta(g, src(e)).location == LOC_SOURCE && 
                _meta(g, dst(e)).location == LOC_PMEM
        )

        edge_var = tensor_graphs[name, first_pmem_edge]

        # If the tensor is created into PMEM, we never write
        @constraint(F.model, tensor_write[name] <= 1 - edge_var)

        # `tensor_write` must be 1 if `edge_var == 1` and any write edge is taken
        edge_iter = filter_edges(g, (g,e) -> _meta(g, e).edgetype == EDGE_WRITE)
        for e in edge_iter
            @constraint(F.model, tensor_write[name] >= tensor_graphs[name, e] - edge_var)
        end

        # If all write edges are not taken, tensor_write must be zero
        @constraint(F.model, tensor_write[name] <= sum(tensor_graphs[name, e] for e in edge_iter))
        add_to_expression!(objective_expr, write_cost, tensor_write[name])
    end

    @variable(F.model,
        tensor_in_dram[
            name = names,
            op = descriptors[name].ops_using_tensor
        ],
        Bin
    )

    # A tensor in DRAM is live if any of its incoming edges are used.
    for name in names
        g = descriptors[name].graph

        #for op in descriptors[name].ops_using_tensor
        for op in descriptors[name].ops_using_tensor
            # Get the DRAM and PREAD vertices for this op.
            vertex = find_vertex(
                g,
                (g,v) -> _meta(g, v).location == LOC_DRAM && _meta(g, v).op == op
            )

            # Map `inedges` to `vertex_iter` and iterats over all those edges
            for e in inedges(g, vertex) 
                @constraint(F.model, tensor_in_dram[name, op] >= tensor_graphs[name, e])
            end

            # If all incoming edges are not taken, tensor MUST not be in DRAM.
            @constraint(F.model,
                sum(tensor_graphs[name, e] for e in inedges(g, vertex)) >= tensor_in_dram[name, op]
            )
        end
    end

    return
end

# There's an issue when trying to reference whether or not a tensor is in DRAM.
#
# If we're on an op where the tensor is used, we have to look at the inputs to a
# graph verted with LOC_DRAM or LOC_PREAD to see if the tensor was fetched or already
# lived in dram.
#
# If we're on an op where a tensor is LIVE but not READ, we need to check the outgoing
# edge of the correct DRAM -> DRAM node to see if the tensor just lives around in DRAM.
function tensor_in_dram(F::Frame{Synchronous}, tensor_name, op)
    # Pull out the descriptor for this tensor - check if this is an op using the tensor.
    descriptor = F.modeltype.descriptors[tensor_name]
    ops_using_tensor = descriptor.ops_using_tensor

    # Sanity check: Make sure that the op passed is between the range of ops that this
    # tensor is live.
    @assert minimum(ops_using_tensor) <= op
    @assert maximum(ops_using_tensor) >= op

    if in(op, ops_using_tensor)
        return F.model[:tensor_in_dram][tensor_name, op]
    else
        ref = reference_op(descriptor, op)
        edge = find_edge(
            descriptor.graph,
            # Source vertex must be in one of the dram locations
            # and outgoing edge must map to the same location.
            (g,e) -> _meta(g, src(e)).location == LOC_DRAM &&
                _meta(g, src(e)).op == ref &&
                _meta(g, dst(e)).location == LOC_DRAM
        )

        # Return the edge in question
        return F.model[:tensor_graphs][tensor_name, edge]
    end
end

function add_nodes!(F::Frame{Synchronous})
    for (op, node_data) in enumerate(F.profile_data.nodes)
        # We don't profile all ops, so perform a quick check to see if this is an op
        # the we have profile information for. If not, there's nothing to do as far as the
        # ILP model is concerned.
        keep(node_data.description) || continue

        configs = collect(keys(node_data.timings))

        # Create a variable for each config.
        vars = @variable(F.model, [config = configs], Bin)

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
                tensor = tensor_in_dram(F, name, op)
                #tensor = tensor_in_dram[name, op]
                if location == DRAM
                    add_to_expression!(expr, tensor)
                    @constraint(F.model, vars[config] <= tensor)
                else
                    add_to_expression!(expr, 1)
                    add_to_expression!(expr, -1, tensor)
                    @constraint(F.model, vars[config] <= 1 - tensor)
                end
            end

            @constraint(F.model, vars[config] + length(config.inputs) + length(config.outputs) >=
                1 + expr)

        end
        # here, we're adding a valid contraint to help the solver
        @constraint(F.model, sum(vars[config] for config in configs) == 1)

        # Mutate the "objective_expr" with these timings
        objective_expr = F.model[:objective_expr]
        for config in configs
            # For now, just use the Mean
            coeff = round(Int64, minimum(node_data.timings[config]))
            add_to_expression!(objective_expr, coeff, vars[config])
        end
    end
    return
end

# Allocations in ngraph happen on 4096 bytes boundaries. For better accuracty, round
# up to the nearest multiple of 4096 before figuring out the number of bytes.
#
# Take the floor to introduce more zeros into the ILP formulation. This shouldn't really
# make much of a difference.
tensor_size(sz) = floor(Int, ceil(Int, sz / 4096) * 4096 / 1E6)

function add_constraints!(F::Frame{Synchronous})
    # Unpack some variables
    dram_limit = limit(F.modeltype)
    tensor_data = F.profile_data.tensors

    # Constrain the live tensors in DRAM to be below a certain threshold.
    for (index, free_tensors) in enumerate(live_tensors(F.profile_data))
        live_free_tensors = filter(!in(F.profile_data.fixed_tensors), free_tensors)
        if !isempty(live_free_tensors)
            @constraint(F.model,
                sum(
                    tensor_size(tensor_data[n].bytes) * 
                    tensor_in_dram(F, n, index) for n in live_free_tensors 
                    if !iszero(tensor_size(tensor_data[n].bytes))) <= dram_limit
            )
        end
    end

    return
end

#####
##### Conifiguration
#####

function get_schedule(F::Frame{Synchronous})
    tensor_names = collect(keys(F.profile_data.tensors))
    model_graphs = F.model[:tensor_graphs]

    schedule = Dict{String, Vector{VertexMetadata}}()

    for tensor_name in tensor_names
        descriptor = F.modeltype.descriptors[tensor_name]
        graph = descriptor.graph

        # Trace the route taken through the graph
        v = find_vertex(graph, (g, v) -> _meta(g, v).location == LOC_SOURCE)

        path = [_meta(graph, v)]
        while _meta(graph, v).location != LOC_SINK
            for e in outedges(graph, v)
                if approx_one(value(model_graphs[tensor_name, e]))
                    v = dst(e)
                    break
                end
            end
            push!(path, _meta(graph, v))
        end
        # Drop the first source element and last sink element
        popfirst!(path)
        pop!(path)

        schedule[tensor_name] = path
    end

    return schedule
end

# Simple struct for keeping track of move nodes that have been inserted for verification
struct InsertedMoveNode
    name::String
    producer::String
    users::Vector{String}
    bytes::Int
    write_to_pmem::Bool
end

function configure!(fex::nGraph.FluxExecutable, F::Frame{Synchronous})
    # Unpack args
    profile_data = F.profile_data
    descriptors = F.modeltype.descriptors
    tensor_graphs = F.model[:tensor_graphs]
    fn = fex.ex.ngraph_function
    _cleanup!(fn)

    # Get the locations of the tensors currently in the graph
    node_dict = Dict(nGraph.name(op) => op for op in fn)
    config = Dict{String, TensorLocation}()

    # Process the move node chains
    schedule = get_schedule(F)
    move_nodes_created = Dict{String, InsertedMoveNode}()
    for (tensor_name, vertices) in schedule

        initial_location = first(vertices).location
        if initial_location == LOC_PMEM
            config[tensor_name] = PMEM
        elseif initial_location == LOC_DRAM
            config[tensor_name] = DRAM
        else
            error("$(initial_location)???")
        end


        # Some preliminary assertions to make sure nothing has gone too far off the rails
        # yet.
        ops_using_tensor = descriptors[tensor_name].ops_using_tensor
        @assert length(vertices) >= length(ops_using_tensor)

        # Get a list of move actions that we will have to perform.
        actions = getactions(vertices)

        incumbent_name = profile_data.tensors[tensor_name].parent_name
        incumbent_index = profile_data.tensors[tensor_name].output_index
        incumbent_tensor = tensor_name
        for action in actions
            # Translate consumers into nodes.
            #
            # We go:
            # consumers -> node_names
            # node_names -> nodes
            node_names = [profile_data.nodes[i].name for i in action.consumers]
            consumers = [node_dict[n] for n in node_names]

            producer = node_dict[incumbent_name]
            consumer_inputs = [
                findfirst(
                    x -> nGraph.get_name(x) == incumbent_tensor, 
                    nGraph.input_descriptors(n)
                ) for n in consumers
            ]
            move_node = insert_move_node!(producer, incumbent_index, consumers, consumer_inputs)

            # Determine associate from the action location.
            #
            # If moving to PMEM, perform this action as soon as possible after the node
            # generating the argument.
            if action.location == PMEM
                nGraph.set_input_affinity(move_node)
                nGraph.add_associate(move_node, incumbent_name)

                #@show nGraph.name(move_node)
                #@show incumbent_name

                # Perform a sanity check. Should not move data to PMEM if it already 
                # started in PMEM.
                @assert initial_location == LOC_DRAM

            # Otherwise, make this happen as late as possible. Add all of the output 
            # associates to this list because scheduling may be reordered after inserting
            # the move nodes.
            elseif action.location == DRAM
                nGraph.set_output_affinity(move_node)
                for nn in node_names
                    nGraph.add_associate(move_node, nn)
                end
            else
                error()
            end

            # Record this move node and the size of the tensor for bandwidth debugging
            move_nodes_created[nGraph.name(move_node)] = InsertedMoveNode(
                nGraph.name(move_node),
                incumbent_name,
                node_names,
                profile_data.tensors[tensor_name].bytes,
                action.location == PMEM,
            )

            # Add this move node to `node_dict` and assign its output tensor to the config.
            output_tensor_name = nGraph.get_name(nGraph.output_descriptor(move_node, 1))
            config[output_tensor_name] = action.location
            node_dict[nGraph.name(move_node)] = move_node

            if action.replace_incumbent
                incumbent_name = nGraph.name(move_node)
                # Since we're just inserting move nodes, the output index will now always
                # be 1
                incumbent_index = 1
                incumbent_tensor = output_tensor_name
            end
        end
    end

    #####
    ##### Apply the config
    #####

    nGraph.get_ordered_ops!(fn)

    # Iterate over each node and each output tensor for each node. Each output tensor should
    # have an assigned location
    for node in fn, output in nGraph.output_descriptors(node)
        if config[nGraph.get_name(output)] == PMEM
            nGraph.make_persistent(output)
        end
    end

    fex = nGraph.recompile(fex)

    #####
    ##### Now, we do some checking to make sure everything is scheduled correctly
    #####
    #verify_moves(fex, move_nodes_created)

    return fex, move_nodes_created
end

function verify_moves(fex::nGraph.FluxExecutable, move_nodes)
    fn = fex.ex.ngraph_function 

    # Iterate through each op, keeping track of the previous op.
    #
    # Every time we get to a "Move" node, check if it is a write to PMEM or read from PMEM.
    # - If write, make sure it immediately follows its producer.
    # - If read, make sure the next op is one of its consumers.
    previous_op = first(fn)
    display_next = false
    for op in Iterators.drop(fn, 1)
        op_name = nGraph.name(op)
        if display_next
            #@show op_name
            display_next = false
        end
        #println()

        if startswith(op_name, "Move")
            metadata = move_nodes[op_name]
            if metadata.write_to_pmem
                @show metadata.producer
                @show nGraph.name(previous_op)
            else
                @show metadata.users
                display_next = true
            end
        end
        previous_op = op
    end
    return nothing
end

# your moves are weak
function profile_moves(fex, args, move_nodes::Dict)
    timing_data = read_timing_data(fex.ex.ngraph_function)
    computed_stats = Dict{String, NamedTuple}()
    for (node_name, stats) in move_nodes
        time = timing_data[findfirst(x -> x["name"] == node_name, timing_data)]["dur"]
        # Convert bytes to GB, time from μs to s
        bandwidth = (stats.bytes / 1E9) / (time / 1E6)
        computed_stats[node_name] = merge(stats, (bandwidth = bandwidth, )) 
    end

    # Summarize read and write bandwidth
    println("Read Bandwidths") 
    for (node_name, stats) in computed_stats
        if stats.write_to_pmem == false
            println("$node_name => $(stats.bandwidth) GB/s")
            println("    size: $(stats.bytes) B")
        end
    end
    println()
    println("Write Bandwidths") 
    for (node_name, stats) in computed_stats
        if stats.write_to_pmem == true
            println("$node_name => $(stats.bandwidth) GB/s")
            println("    size: $(stats.bytes) B")
        end
    end

    return computed_stats
end

#=
Okay, so converting the schedule of move operation into a useable form actual turs out to
be more complicated than I originally thought.
=#

struct MoveAction
    consumers::Vector{Int}
    location::TensorLocation
    replace_incumbent::Bool
end

# Consume all of the PKEEP nodes.
function getkeeps(vertices::Vector{VertexMetadata}, index)
    keeps = Int[]
    while checkbounds(Bool, vertices, index) && vertices[index].location == LOC_DRAM
        push!(keeps, vertices[index].op)
        index += 1
    end
    return unique(keeps)
end

# Return `true` if there is an implied write to
write_to_pmem(a, b) = a == LOC_DRAM && b == LOC_PMEM
read_from_pmem(a, b) = a == LOC_PMEM && b == LOC_DRAM

function getactions(vertices::Vector{VertexMetadata})
    actions = MoveAction[]

    data_in_pmem = false
    isfirst = true

    for i in Iterators.drop(eachindex(vertices), 1)
        a, b = vertices[i-1].location, vertices[i].location

        # If we're on the first iteration and the location of `b` is PMEM, then we
        # will never write to PMEM
        if isfirst
            if a == LOC_PMEM 
                data_in_pmem = true
            end
            isfirst = false
        end

        if !data_in_pmem && write_to_pmem(a, b)
            # All downstream users are consumers
            consumers = unique(vertices[i].op for i in i:length(vertices))
            push!(actions, MoveAction(consumers, PMEM, true))
            data_in_pmem = true
        end

        if read_from_pmem(a, b)
            consumers = getkeeps(vertices, i)
            push!(actions, MoveAction(consumers, DRAM, false))
        end
    end

    # Need to filter out the first op from showing up in the actions because the first op
    # doesn't actually use the tensor - it produces it.
    producing_op = first(vertices).op 

    for action in actions
        filter!(!isequal(producing_op), action.consumers)
    end
    return actions
end
