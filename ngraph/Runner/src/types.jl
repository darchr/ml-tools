#####
##### Creation Contexts
#####

abstract type AbstractCreationContext end

struct AllTensors <: AbstractCreationContext end
struct OnlyIntermediate <: AbstractCreationContext end

#####
##### TensorWrapper
#####

struct TensorWrapper
    tensor::nGraph.TensorDescriptor
end
unwrap(a::TensorWrapper) = a.tensor

JuMP.name(a::TensorWrapper) = nGraph.get_name(unwrap(a))

rawptr(a::TensorWrapper) = nGraph.getpointer(unwrap(a))[]
Base.:(==)(a::TensorWrapper, b::TensorWrapper) = rawptr(a) == rawptr(b)
Base.hash(a::TensorWrapper, h::UInt = convert(UInt, 0x23089234)) = hash(rawptr(a), h)

Base.sizeof(a::TensorWrapper) = sizeof(unwrap(a))
is_persistent(a::TensorWrapper) = nGraph.is_persistent(unwrap(a))

#####
##### Node Wrapper
#####

struct NodeWrapper
    node::nGraph.Node
    timings::Dict{IOConfig, Vector{Float64}}
end

NodeWrapper(n::nGraph.Node) = NodeWrapper(n, Dict{IOConfig, Vector{Float64}}())
Base.show(io::IO, n::NodeWrapper) = print(io, name(n))

unwrap(n::NodeWrapper) = n.node

JuMP.name(n::NodeWrapper) = nGraph.name(unwrap(n))

rawptr(a::NodeWrapper) = nGraph.getpointer(unwrap(a))[]

description(n::NodeWrapper) = nGraph.description(unwrap(n))
isconstant(n::NodeWrapper) = description(n) == "Constant"

Base.:(==)(n::NodeWrapper, m::NodeWrapper) = rawptr(n) == rawptr(m)
Base.hash(n::NodeWrapper, h::UInt = UInt(0x4029388)) = hash(rawptr(n), h)

outputs(n::NodeWrapper) = TensorWrapper.(nGraph.output_descriptors(unwrap(n)))
inputs(n::NodeWrapper) = TensorWrapper.(nGraph.input_descriptors(unwrap(n)))

hasprofile(x::NodeWrapper) = hasprofile(description(x))

#####
##### Profile Data
#####

struct ProfileData{C <: AbstractCreationContext}
    tensors::Vector{TensorWrapper}

    # Stored in program order.
    nodes::Vector{NodeWrapper}

    # Liveness Analysis
    newlist::Vector{Vector{TensorWrapper}}
    freelist::Vector{Vector{TensorWrapper}}
    io_tensors::Set{TensorWrapper}
    constant_tensors::Set{TensorWrapper}

    # Metadat to speed up down-stream algorithms
    users::Dict{TensorWrapper, Vector{NodeWrapper}}
end

nodes(P::ProfileData) = P.nodes
nodes(P::ProfileData, inds...) = getindex(P.nodes, inds...)

tensors(P::ProfileData) = P.tensors

_producer(tensor::TensorWrapper, P::ProfileData) = first(P.users[tensor])
_consumer(tensor::TensorWrapper, P::ProfileData) = last(P.users[tensor])
_users(tensor::TensorWrapper, P::ProfileData) = P.users[tensor]

function ProfileData(fex::nGraph.FluxExecutable, ctx = OnlyIntermediate())
    fn = fex.ex.ngraph_function

    # Construct the tensors and nodes fields
    tensors = TensorWrapper[]
    nodes = NodeWrapper[]
    users = Dict{TensorWrapper, Vector{NodeWrapper}}()
    for op in fn
        wrapped = NodeWrapper(op)
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
    parameters = Iterators.flatten(outputs.(NodeWrapper.(nGraph.get_parameters(fn)))) 
    results = Iterators.flatten(outputs.(NodeWrapper.(nGraph.get_results(fn))))

    @timeit TO "io_tensors" io_tensors = Set(Iterators.flatten((parameters, results)))
    constant_tensors = Set{TensorWrapper}()
    @timeit TO "constant_tensors" for node in nodes
        if isconstant(node)
            for tensor in outputs(node)
                push!(constant_tensors, tensor)
            end
        end
    end

    @show length(io_tensors)

    @timeit TO "liveness" begin
        liveness = liveness_analysis(ctx, nodes, io_tensors, constant_tensors)
    end

    PD = ProfileData{typeof(ctx)}(
        tensors,
        nodes,
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

# Many of the downstream algorithms can be tuned by messing with liveness analysis.
#
# When we're optimizing over all tensors (i.e. considering inputs and outputs), then we must
# consider the inputs, outputs, and constants and live for the whole duration of the function.
#
# On the other hand, if we're only optimizing over intermediate tensors, we don't want 
# the io/constants showing up.

_fill_first(::AllTensors, new_list, io, constants) = new_list[1] = vcat(collect.((io, constants))...) 
_fill_first(::OnlyIntermediate, args...) = nothing

_add_filter(::AbstractCreationContext, tensors, io, constants) = 
    filter(x -> !in(x, io) && !in(x, constants), tensors)

_can_free(::AbstractCreationContext, tensor::TensorWrapper, freed, io, constants) =
    !any(x -> in(tensor, x), (freed, io, constants))

function liveness_analysis(ctx::AbstractCreationContext, nodes::Vector{NodeWrapper}, io, constants)
    new_list = [TensorWrapper[] for _ in nodes]
    free_list = [TensorWrapper[] for _ in nodes]

    # Initialize the first entry in the table
    _fill_first(ctx, new_list, io, constants)

    # Forward Pass
    for (index, op) in Iterators.drop(enumerate(nodes), 1)
        new_list[index] = _add_filter(ctx, outputs(op), io, constants)
    end

    # Backward Pass
    freed_tensors = Set{TensorWrapper}() 
    for (index, op) in enumerate(reverse(nodes))
        for tensor in inputs(op)
            if _can_free(ctx, tensor, freed_tensors, io, constants)
                push!(free_list[end + 1 - index], tensor)
                push!(freed_tensors, tensor)
            end
        end
    end

    return (new_list = new_list, free_list = free_list)
end

# Convenience for iterating over live tensors
struct LiveTensorIterator{C}
    data::ProfileData{C}
    live_tensors::Set{TensorWrapper}
end

_live_tensor_init(data::ProfileData{AllTensors}) = 
    Set(Iterators.flatten((data.io_tensors, data.constant_tensors)))
_live_tensor_init(data::ProfileData{OnlyIntermediate}) = Set{TensorWrapper}()

live_tensors(data::ProfileData) = LiveTensorIterator(data, _live_tensor_init(data))

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

function locations(data::ProfileData{AllTensors}, tensor::TensorWrapper)
    # Now, constants are the only items that are fixed.
    if isconstant(_producer(tensor, data))
        return [DRAM]
    else
        return [DRAM, PMEM]
    end
end

# TODO: These might not be perfect ...
isparam(t::NodeWrapper) = startswith(name(t), "Parameter")
isresult(t::NodeWrapper) = startswith(name(t), "Result")

function locations(data::ProfileData{OnlyIntermediate}, tensor::TensorWrapper)
    producer = _producer(tensor, data)
    if isconstant(producer) || isparam(producer) || isresult(producer)
        return [DRAM]
    else
        return [DRAM, PMEM]
    end
end

function get_configs(data::ProfileData)
    configs = Set{Tuple{NodeWrapper, IOConfig}}()
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
    input = map(f, nGraph.input_descriptors(n)) |> Tuple
    output = map(f, nGraph.output_descriptors(n)) |> Tuple

    return IOConfig(input, output)
end

#####
##### Setup and cleanup code
#####

function _setup!(node::nGraph.Node, config::IOConfig)
    # Outputs
    for (i, location) in enumerate(config.outputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.output_descriptor(node, i))
        end
    end

    # Inputs
    for (i, location) in enumerate(config.inputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.input_descriptor(node, i))
        end
    end
end

# Set everything back to volatile
_cleanup!(f::nGraph.NFunction) = map(_cleanup!, f)

function _cleanup!(node::nGraph.Node)
    for descriptor in nGraph.output_descriptors(node)
        nGraph.make_volatile(descriptor)
        nGraph.reset_offset(descriptor)
    end
    for descriptor in nGraph.input_descriptors(node)
        nGraph.make_volatile(descriptor)
        nGraph.reset_offset(descriptor)
    end
end
