#####
##### TensorWrapper
#####

struct TensorWrapper
    tensor::nGraph.TensorDescriptor
end
unwrap(a::TensorWrapper) = a.tensor

JuMP.name(a::TensorWrapper) = nGraph.get_name(unwrap(a))
Base.:(==)(a::TensorWrapper, b::TensorWrapper) = name(a) == name(b)
Base.hash(a::TensorWrapper, h::UInt = convert(UInt, 0x23089234)) = hash(name(a), h)

Base.sizeof(a::TensorWrapper) = sizeof(unwrap(a))

#####
##### Node Wrapper
#####

struct NodeWrapper
    node::nGraph.Node
    timings::Dict{IOConfig, Vector{Float64}}
end

NodeWrapper(n::nGraph.Node) = NodeWrapper(n, Dict{IOConfig, Vector{Float64}}())

unwrap(n::NodeWrapper) = n.node

JuMP.name(n::NodeWrapper) = nGraph.name(unwrap(n))
description(n::NodeWrapper) = nGraph.description(unwrap(n))
isconstant(n::NodeWrapper) = description(n) == "Constant"

Base.:(==)(n::NodeWrapper, m::NodeWrapper) = (name(m) == name(n))
Base.hash(n::NodeWrapper, h::UInt = UInt(0x4029388)) = hash(name(n), h)

outputs(n::NodeWrapper) = TensorWrapper.(nGraph.output_descriptors(unwrap(n)))
inputs(n::NodeWrapper) = TensorWrapper.(nGraph.input_descriptors(unwrap(n)))

keep(x::NodeWrapper) = keep(description(x))

#####
##### Profile Data
#####

struct ProfileData
    tensors::Vector{TensorWrapper}

    # Stored in program order.
    nodes::Vector{NodeWrapper}

    # Liveness Analysis
    newlist::Vector{Vector{TensorWrapper}}
    freelist::Vector{Vector{TensorWrapper}}
    io_tensors::Set{TensorWrapper}
    constant_tensors::Set{TensorWrapper}
end

nodes(P::ProfileData) = P.nodes
tensors(P::ProfileData) = P.tensors

function ProfileData(fex::nGraph.FluxExecutable)
    fn = fex.ex.ngraph_function

    # Construct the tensors and nodes fields
    tensors = TensorWrapper[]
    nodes = NodeWrapper[]
    for op in fn
        wrapped = NodeWrapper(op)
        push!(nodes, wrapped)
        for tensor in outputs(wrapped)
            push!(tensors, tensor)
        end
    end

    # How, perform the liveness analysis on the nodes and tensors data structures
    io_tensors = Set(t for t in tensors if isparam(fex, t) || isresult(fex, t))
    constant_tensors = Set(t for t in tensors if isconstant(_producer(t, nodes)))

    @show length(io_tensors)

    liveness = liveness_analysis(nodes, io_tensors, constant_tensors)

    PD = ProfileData(
        tensors,
        nodes,
        liveness.new_list,
        liveness.free_list,
        io_tensors,
        constant_tensors
    )
    #set_tensor_locations!(PD, fn)
    return PD
end

function liveness_analysis(nodes::Vector{NodeWrapper}, io_tensors, constant_tensors)
    new_list = [TensorWrapper[] for _ in nodes]
    free_list = [TensorWrapper[] for _ in nodes]

    new_list[1] = vcat(collect(io_tensors), collect(constant_tensors))

    # Forward Pass
    for (index, op) in Iterators.drop(enumerate(nodes), 1)
        new_list[index] = filter(x -> !in(x, io_tensors) && !in(x, constant_tensors), outputs(op))
    end

    # Backward Pass
    freed_tensors = Set{TensorWrapper}() 
    for (index, op) in enumerate(reverse(nodes))
        for tensor in inputs(op)
            if !any(x -> in(tensor, x), (freed_tensors, io_tensors, constant_tensors))
                push!(free_list[end + 1 - index], tensor)
                push!(freed_tensors, tensor)
            end
        end
    end

    return (new_list = new_list, free_list = free_list)
end

struct LiveTensorIterator
    data::ProfileData
    live_tensors::Set{TensorWrapper}
end

function live_tensors(data::ProfileData) 
    init = Set(Iterators.flatten((data.io_tensors, data.constant_tensors)))
    LiveTensorIterator(data, init)
end

Base.length(L::LiveTensorIterator) = length(L.data.newlist)
function Base.iterate(L::LiveTensorIterator, s = 1)
    s > length(L) && return nothing

    # Free tensors from the previous iteration
    if s > 1
        for tensor in L.data.freelist[s-1]
            if !in(tensor, L.data.io_tensors) && !in(tensor, L.data.constant_tensors)
                delete!(L.live_tensors, tensor)
            end
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

function locations(data::ProfileData, tensor::TensorWrapper)
    # Now, constants are the only items that are fixed.
    if isconstant(_producer(tensor, nodes(data)))
        return [DRAM]
    else
        return [DRAM, PMEM]
    end
end

function get_configs(data::ProfileData)
    configs = Set{Tuple{NodeWrapper, IOConfig}}()
    for node in nodes(data)
        keep(node) || continue

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
