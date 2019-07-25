# This is how we get the ILP (or other optimization routines) back to ngraph


# Struct for keeping track of what tensors are moved.
#
# children: Maps a tensor `t` to the collection tensors that are the results of "Move"
#   instructions ultimately beginning at `t`.
# parent: Maps a tensor `t` to its parent tensor. The following should hold: `t ∈ children[parent[t]]`
struct TensorMap
    children::Dict{TensorDescriptor, Vector{TensorDescriptor}}
    parent::Dict{TensorDescriptor, TensorDescriptor}
end
TensorMap() = TensorMap(
    Dict{TensorDescriptor, Vector{TensorDescriptor}}(),
    Dict{TensorDescriptor, TensorDescriptor}()
)

function addtensor!(M::TensorMap, d::TensorDescriptor)
    @assert !haskey(M.children, d)
    @assert !haskey(M.parent, d)

    M.children[d] = TensorDescriptor[]
    M.parent[d] = d
end

function addchild!(M::TensorMap, parent::TensorDescriptor, child::TensorDescriptor)
    push!(M.children[parent], child)
    M.parent[child] = parent
end

getchildren(M::TensorMap, parent) = M.children[parent]
getparent(M::TensorMap, child) = M.parent[child]
isparent(M::TensorMap, tensor) = getparent(M, tensor) == tensor

#####
##### Conifiguration
#####

struct MoveAction
    consumers::Vector{NodeDescriptor}
    location::TensorLocation
    replace_incumbent::Bool
    # Additional data needed for "asynchronous" moves
    concurrent::Union{Nothing, NodeDescriptor}
end
isasync(M::MoveAction) = !isnothing(M.concurrent)

function _initial_loc(path)
    initial_location = first(path).location
    if initial_location == LOC_PMEM
        return PMEM
    elseif isdram(initial_location)
        return DRAM
    else
        error("$(initial_location)???")
    end
end

function configure!(f, frame::Frame)
    # Get initial schedules for the frame
    initial_schedule = get_schedule(frame)

    # Convert this into an appropriate format for the inner `configure!`
    schedule = Dict(
        t => (_initial_loc(path), getactions(tensor_graph, path))
        for (t, (tensor_graph, path)) in initial_schedule
    )

    # TODO: Move this into the innermost `configure!`
    data = frame.profile_data
    for node in nodes(data)
        if nGraph.Lib.can_select_algo(nGraph.getpointer(node))
            # Only access this once we know that there is at least one node where the
            # algorithm can be decided.
            #
            # Otherwise, `frame.model[:algo_var]` will not be defined.
            algo_var = frame.model[:algo_var]
            count = 0
            local algo_enum
            for enum in get_enums(gettime(data, node))
                if approx_one(algo_var[node,enum])
                    count += 1
                    algo_enum = enum
                end
            end

            # Only one algorithm should be selected
            @assert count == 1
            nGraph.Lib.set_algo(
                nGraph.getpointer(node),
                convert(UInt, algo_enum),
                convert(UInt, get_bytes(gettime(data, node), algo_enum))
            )
        end
    end

    @info "Calling Inner Configure"
    return configure!(f, frame.profile_data, schedule)
end

function configure!(fex::nGraph.FluxExecutable, data::ProfileData, schedule)
    f = fex.ex.ngraph_function
    tensor_map = configure!(f, data, schedule)

    @info "Recompiling Function"
    fex = nGraph.recompile(fex)

    return fex, tensor_map
end

function configure!(fn::nGraph.NFunction, data::ProfileData, schedule, algos = nothing)
    # Unpack args
    _cleanup!(fn)

    # Get the locations of the tensors currently in the graph
    config = Dict{TensorDescriptor, TensorLocation}()

    # Process the move node chains
    tensor_map = TensorMap()

    # We find all nodes that are targets of a move to DRAM and insert a synchronization
    # barrier.
    #
    # We only do this once for each target because a synchronization barrier will
    # synchronize ALL asynchronous moves
    #
    # KEY: The node that has at least one input coming from an async move
    # VALUE: An async move to this node.
    synced_nodes = Set{nGraph.NodeDescriptor}()

    for (tensor, (initial_location, actions)) in schedule
        addtensor!(tensor_map, tensor)
        config[tensor] = initial_location

        producer = _producer(tensor, data)
        producer_output = findonly(isequal(tensor), outputs(producer))
        incumbent = tensor

        for action in actions

            consumers = action.consumers
            consumer_inputs = [findonly(isequal(incumbent), inputs(n)) for n in consumers]

            if isasync(action)
                move_node = insert_moveasync_node!(
                    producer,
                    producer_output,
                    consumers,
                    consumer_inputs,
                    action.concurrent;
                )

                if !ismove(producer)
                    @assert data.node_to_index[producer] < data.node_to_index[action.concurrent]
                end
            else
                move_node = insert_move_node!(
                    producer,
                    producer_output,
                    consumers,
                    consumer_inputs,
                )
            end

            # Add the new output tensor tothe tensor map
            for output in outputs(move_node)
                addchild!(tensor_map, tensor, output)
            end

            # Quick debug
            if action.location == PMEM && !isasync(action)
                @assert initial_location == DRAM
            end

            # Add this move node to `node_dict` and assign its output tensor to the config.
            output_tensor = first(outputs(move_node))
            config[output_tensor] = action.location

            if action.replace_incumbent
                producer = move_node
                # Since we're just inserting move nodes, the output index will now always
                # be 1
                producer_output = 1
                incumbent = output_tensor
            end
        end
    end

    #####
    ##### Apply the config
    #####

    # Iterate over each node and each output tensor for each node. Each output tensor should
    # have an assigned location
    for node in fn, output in outputs(NodeDescriptor(node))
        if config[output] == PMEM
            make_persistent(output)
        end
    end

    # Run priority pass after configuration
    priority_pass!(fn)

    # Set algorithms and workspaces
    return tensor_map
end

# Get the path of the tensor traced through the graph
function get_schedule(F::Frame)
    data = F.profile_data
    model_graphs = F.model[:tensor_graphs]

    schedule = Dict{TensorDescriptor, Tuple{MetaGraph, Vector{VertexMetadata}}}()

    for tensor in tensors(data)
        g = graph(descriptor(F, tensor))

        # Trace the route taken through the graph
        v = find_vertex(g, (g, v) -> _meta(g, v).location == LOC_SOURCE)

        path = [_meta(g, v)]
        seen = Int[]
        while _meta(g, v).location != LOC_SINK
            if isempty(outedges(g, v)) || in(v, seen)
                error("""
                $tensor
                $(_meta(g, v))
                """)
            end

            push!(seen, v)
            for e in outedges(g, v)
                if approx_one(model_graphs[tensor, e])
                    v = dst(e)
                    break
                end
            end
            push!(path, _meta(g, v))
        end
        # Drop the first source element and last sink element
        popfirst!(path)
        pop!(path)

        schedule[tensor] = (g, path)
    end

    return schedule
end

# Consume all of the PKEEP nodes.
function getkeeps(vertices::Vector{VertexMetadata}, index)
    keeps = NodeDescriptor[]
    while checkbounds(Bool, vertices, index) && isdram(vertices[index].location)
        vertex = vertices[index]
        if vertex.isuser
            push!(keeps, vertices[index].op)
        end
        index += 1
    end
    return unique(keeps)
end

function isasync(tensor_graph, a::VertexMetadata, b::VertexMetadata)
    # Get the vertex number from the metadata - construct the edge
    src = a.vertex_number
    dst = b.vertex_number
    edge_metadata = _meta(tensor_graph, edgetype(tensor_graph)(src, dst))
    return isasync(edge_metadata)
end

# Return `true` if there is an implied write to
write_to_pmem(a, b) = a == LOC_DRAM_PRE && ispmem(b)
read_from_pmem(a, b) = ispmem(a) && isdram(b)

function getactions(tensor_graph, vertices::Vector{VertexMetadata})
    actions = MoveAction[]
    written_to_pmem = false

    for i in Iterators.drop(eachindex(vertices), 1)
        src = vertices[i-1]
        dst = vertices[i]
        a, b = src.location, dst.location

        # Determine whether this is an asynchronous move
        if isasync(tensor_graph, src, dst)
            concurrent = src.op
        else
            concurrent = nothing
        end

        if write_to_pmem(a, b)
            if written_to_pmem
                @show actions
                error()
            end
            # All downstream users are consumers
            consumers = unique(vertices[i].op for i in i:length(vertices) if vertices[i].isuser)

            # One solution to the ILP is to move data back and forth if it does not cause
            # any additional overhead.
            #
            # Here, we just filter out these movements by checking if the consumers of a
            # move is empty
            if !isempty(consumers)
                push!(actions, MoveAction(consumers, PMEM, true, concurrent))
                written_to_pmem = true
            end
        end

        if read_from_pmem(a, b)
            consumers = getkeeps(vertices, i)
            if !isempty(consumers)
                push!(actions, MoveAction(consumers, DRAM, false, concurrent))
            end
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

#####
##### Misc Stuff
#####

estimate_move_time(fex::nGraph.FluxExecutable, frame::Frame{ILPHolder{IsFixed}}) = zero(Float64)
estimate_move_time(fex::nGraph.FluxExecutable, frame::Frame) = 
    estimate_move_time(fex.ex.ngraph_function, frame)

function estimate_move_time(f::nGraph.NFunction, frame::Frame)
    move_time = zero(Float64)
    for _node in f
        node = NodeDescriptor(_node)

        # If this is a move, determine which direction data is being moved and add the move
        # time estimate to the rolling counter.
        if description(node) == "Move"
            tensor = first(outputs(node))
            if nGraph.is_persistent(tensor)
                move_time += sizeof(tensor) / wb(frame.modeltype)
            else
                move_time += sizeof(tensor) / rb(frame.modeltype)
            end
        end
    end
    return move_time
end


# your moves are weak
function profile_moves(fex)
    timing_data = read_timing_data(fex.ex.ngraph_function)
    computed_stats = Dict{String, NamedTuple}()
    for node_unwrapped in fex.ex.ngraph_function
        node = NodeDescriptor(node_unwrapped)
        ismove(node) || continue

        time = timing_data[findfirst(x -> x["name"] == nGraph.name(node), timing_data)]["dur"]
        # Convert bytes to GB, time from μs to s
        bytes = sizeof(first(inputs(node)))
        bandwidth = (bytes / 1E9) / (time / 1E6)
        computed_stats[nGraph.name(node)] = (
            bytes = bytes,
            bandwidth = bandwidth,
            write_to_pmem = !nGraph.is_persistent(first(inputs(node))),
        )
    end

    # Summarize read and write bandwidth
    println("Read Bandwidths")
    for f in (ismoveasync, !ismoveasync)
        s = 0
        count = 0
        for (node_name, stats) in computed_stats
            f(node_name) || continue
            if stats.write_to_pmem == false
                println("$node_name => $(stats.bandwidth) GB/s")
                println("    size: $(stats.bytes) B")

                if !isinf(stats.bandwidth)
                    s += stats.bandwidth
                    count += 1
                end
            end
        end

        println()
        println("Average Bandwidth: ", s / count)
        println()
    end
    println()
    println("Write Bandwidths")
    for f in (ismoveasync, !ismoveasync)
        s = 0
        count = 0
        for (node_name, stats) in computed_stats
            f(node_name) || continue
            if stats.write_to_pmem == true
                println("$node_name => $(stats.bandwidth) GB/s")
                println("    size: $(stats.bytes) B")

                if !isinf(stats.bandwidth)
                    s += stats.bandwidth
                    count += 1
                end
            end
        end
        println()
        println("Average Bandwidth: ", s / count)
        println()
    end

    return computed_stats
end

