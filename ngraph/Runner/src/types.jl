#####
##### Profile Data
#####

struct ProfileData
    tensors::Vector{TensorDescriptor}

    # Stored in program order.
    nodes::Vector{NodeDescriptor}
    node_to_index::Dict{NodeDescriptor, Int}
    timings::Dict{NodeDescriptor, Dict{IOConfig, Float64}}

    # Liveness Analysis
    newlist::Vector{Vector{TensorDescriptor}}
    freelist::Vector{Vector{TensorDescriptor}}
    io_tensors::Set{TensorDescriptor}
    constant_tensors::Set{TensorDescriptor}

    # Metadata to speed up down-stream algorithms
    users::Dict{TensorDescriptor, Vector{NodeDescriptor}}
end

function settime!(P::ProfileData, N::NodeDescriptor, config, time) 
    d = get!(P.timings, N, Dict{IOConfig, Float64}())
    d[config] = time
end

gettime(P::ProfileData, N::NodeDescriptor) = P.timings[N]
gettime(P::ProfileData, N::NodeDescriptor, config) = P.timings[N][config]

hastime(P::ProfileData, N::NodeDescriptor, config) =
    haskey(P.timings, N) && haskey(P.timings, config)

nodes(P::ProfileData) = P.nodes
nodes(P::ProfileData, inds...) = getindex(P.nodes, inds...)

tensors(P::ProfileData) = P.tensors

_producer(tensor::TensorDescriptor, P::ProfileData) = first(P.users[tensor])
_consumer(tensor::TensorDescriptor, P::ProfileData) = last(P.users[tensor])
_users(tensor::TensorDescriptor, P::ProfileData) = P.users[tensor]

function ProfileData(fex::nGraph.FluxExecutable)
    fn = fex.ex.ngraph_function

    # Construct the tensors and nodes fields
    tensors = TensorDescriptor[]
    nodes = NodeDescriptor[]
    users = Dict{TensorDescriptor, Vector{NodeDescriptor}}()
    for op in fn
        wrapped = NodeDescriptor(op)
        push!(nodes, wrapped)
        # Record the tensors. Also record the users at this time for convenience
        for tensor in outputs(wrapped)
            push!(tensors, tensor)
            users[tensor] = [wrapped]
        end
        for tensor in inputs(wrapped)
            if !in(wrapped, users[tensor])
                push!(users[tensor], wrapped)
            end
        end
    end

    # Perform the liveness analysis on the nodes and tensors data structures
    parameters = Iterators.flatten(outputs.(NodeDescriptor.(nGraph.get_parameters(fn))))
    results = Iterators.flatten(outputs.(NodeDescriptor.(nGraph.get_results(fn))))

    @timeit TO "io_tensors" io_tensors = Set(Iterators.flatten((parameters, results)))
    constant_tensors = Set{TensorDescriptor}()
    @timeit TO "constant_tensors" for node in nodes
        if isconstant(node)
            for tensor in outputs(node)
                push!(constant_tensors, tensor)
            end
        end
    end

    @show length(io_tensors)

    @timeit TO "liveness" begin
        liveness = liveness_analysis(nodes, io_tensors, constant_tensors)
    end

    PD = ProfileData(
        tensors,
        nodes,
        Dict(n => i for (i,n) in enumerate(nodes)),
        Dict{NodeDescriptor, Dict{IOConfig, Float64}}(),
        liveness.new_list,
        liveness.free_list,
        io_tensors,
        constant_tensors,
        users
    )
    return PD
end

#####
##### Context Dependent Liveness Analysis
#####

_can_free(tensor::TensorDescriptor, freed, io, constants) =
    !any(x -> in(tensor, x), (freed, io, constants))

function liveness_analysis(nodes::Vector{NodeDescriptor}, io, constants)
    new_list = [TensorDescriptor[] for _ in nodes]
    free_list = [TensorDescriptor[] for _ in nodes]

    # Forward Pass
    for (index, op) in enumerate(nodes)
        new_list[index] = filter(x -> !in(x, io) && !in(x, constants), outputs(op))
    end

    # Backward Pass
    freed_tensors = Set{TensorDescriptor}()
    for (index, op) in enumerate(reverse(nodes))
        for tensor in inputs(op)
            if _can_free(tensor, freed_tensors, io, constants)
                push!(free_list[end + 1 - index], tensor)
                push!(freed_tensors, tensor)
            end
        end
    end

    return (new_list = new_list, free_list = free_list)
end

# Convenience for iterating over live tensors
struct LiveTensorIterator
    data::ProfileData
    live_tensors::Set{TensorDescriptor}
end

live_tensors(data::ProfileData) = LiveTensorIterator(data, Set{TensorDescriptor}())
Base.length(L::LiveTensorIterator) = length(L.data.newlist)
function Base.iterate(L::LiveTensorIterator, s = 1)
    s > length(L) && return nothing

    # Free tensors from the previous iteration
    if !isone(s)
        for tensor in L.data.freelist[s-1]
            delete!(L.live_tensors, tensor)
        end
    end

    # Add new tensors for this iteration
    for tensor in L.data.newlist[s]
        push!(L.live_tensors, tensor)
    end

    return L.live_tensors, s+1
end


"""
    allocation_bounds(data::ProfileData)

Return upper and lower bounds on the amount of DRAM required for input, output,
constant, and intermediate tensors.

Upper bound is determined by the maximum tensors concurrently live.

Lower bound is determined by the total size of input, output, and constant tensors.
"""
function allocation_bounds(data::ProfileData)
    # Lower bound should always be zero since we're ignoring fixed tensors
    lower_bound = sum(sizeof.(data.constant_tensors))

    # Compute Upper Bound
    upper_bound = 0
    for tensors in live_tensors(data)
        if !isempty(tensors)
            upper_bound = max(upper_bound, sum(sizeof(n) for n in tensors))
        end
    end

    return (upper_bound = upper_bound, lower_bound = lower_bound)
end

#####
##### Valid locations that a tensor can live
#####

function locations(data::ProfileData, tensor::TensorDescriptor)
    producer = _producer(tensor, data)
    if isconstant(producer) || isparam(producer) || isresult(producer)
        return [DRAM]
    else
        return [DRAM, PMEM]
    end
end

function get_configs(data::ProfileData)
    configs = Set{Tuple{NodeDescriptor, IOConfig}}()
    for node in nodes(data)
        hasprofile(node) || continue

        config_inputs = [locations(data, t) for t in inputs(node)]
        config_outputs = [locations(data, t) for t in outputs(node)]

        for input_config in Iterators.product(config_inputs...)
            for output_config in Iterators.product(config_outputs...)
                config = IOConfig(input_config, output_config)
                push!(configs, (node, config))
            end
        end
    end
    return configs
end

function getconfig(n::nGraph.Node)
    f = x -> nGraph.is_persistent(x) ? PMEM : DRAM
    input = map(f, inputs(n)) |> Tuple
    output = map(f, outputs(n)) |> Tuple

    return IOConfig(input, output)
end

#####
##### Setup and cleanup code
#####

function _setup!(node::nGraph.Node, config::IOConfig)
    # Outputs
    for (i, location) in enumerate(config.outputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.output(node, i))
        end
    end

    # Inputs
    for (i, location) in enumerate(config.inputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.input(node, i))
        end
    end
end

# Set everything back to volatile
_cleanup!(f::nGraph.NFunction) = map(_cleanup!, f)

function _cleanup!(node::nGraph.Node)
    for descriptor in outputs(node)
        nGraph.make_volatile(descriptor)
        nGraph.reset_offset(descriptor)
    end
    for descriptor in inputs(node)
        nGraph.make_volatile(descriptor)
        nGraph.reset_offset(descriptor)
    end
end

#####
##### For gathering statistics
#####

_move_filter() = x -> ismove(x) && !ismoveasync(x)
_async_filter() = x -> ismoveasync(x)

function _move_filter(dest)
    is_persistent_result = (dest == PMEM) ? true : false

    return x -> ismove(x) && nGraph.is_persistent(first(outputs(x))) == is_persistent_result
end

function _async_filter(dest)
    is_persistent_result = (dest == PMEM) ? true : false

    return x -> _async_filter()(x) && nGraph.is_persistent(first(outputs(x))) == is_persistent_result
end

# Count metrics
_count(f, data; kw...) = _count(f, x -> 1, data; kw...)
function _count(f, g, data; filt = x -> true)
    count = 0
    for node in filter(filt, nodes(data))
        for tensor in f(node)
            count += g(tensor)
        end
    end
    return count
end
