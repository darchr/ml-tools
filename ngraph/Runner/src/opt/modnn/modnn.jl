include("allocator.jl")

@enum IntermediateTensorLocation UNALLOC ALLOCED_DRAM ALLOCED_PMEM

mutable struct moDNNTensorMeta
    # Current location
    location::IntermediateTensorLocation

    # If current location is in DRAM, this offset points to the allocation offset
    offset::Int64

    # Flag to indicate if this tensor has been used since its last prefetch or generation
    been_used::Bool

    actions::Vector{MoveAction}  
end


# Implementation of the moDNN algorithm, adjusted for the PMM/DRAM case.
function schedule(fex::nGraph.FluxExecutable, data::ProfileData, limit)
    # T is the current time
    T = 0

    # Initilize tensor metadata for each tensor
    meta = Dict(
        t => moDNNTensorMeta(UNALLOC, -1, true, MoveAction[]) for t in tensor(data)
    )
    pool = MemoryAllocator(limit, 4096)

    # Iterate through the nodes in the graph in topological order
    for node in nodes(data) 
        # try to allocate. If allocation fails, find an offloading scheme
        # (which may cause defragmentation)
        #
        # Then try to reallocate
        if !(allocate_io!(pool, meta, node))
            offload!(pool, meta, node, data)
        end
        load data
    end
end

#####
##### Tensor IO Allocation
#####

function allocate_io!(pool, meta, node)
    # Check the location of all inputs to the node in DRAM. If not, try to allocate space
    # for them. 
    input_offsets = Dict(
        t => allocate(pool, sizeof(t)) for t in inputs(node) 
        if meta[t].location != ALLOCED_DRAM
    )

    # If any of the input allocations failed, free anything we allocated are return `false`.
    if any(isnothing, values(input_offsets)) 
        free.(Ref(pool), values(input_offsets))
        return false
    end

    # We've successfully allocated inputs, try to allocate the outputs
    output_offsets = Dict(t => allocate(pool, sizeof(t)) for t in outputs(node))
    if any(isnothing, values(output_offsets))
        free.(Ref(pool), values(output_offsets))
        free.(Ref(pool), values(input_offsets))
        return false
    end

    # At this point, we've allocated everything. 
    #
    # Update the input tensors. This may involve updating the actions associated with them,
    # so call into `dram_update!` which takes care of those details
    for (tensor, offset) in input_offsets
        dram_update!(meta[tensor], offset, node)
    end

    # We assume all output tensors get produced straight to DRAM, so adjusting the metadata
    # for the output tensors is easier.
    #
    # Just mark their offset and set their `usage` flag to `false` to avoid immediate 
    # offloading.
    for (tensor, offset) in output_offsets
        tensor_meta = meta[tensor]

        tensor_meta.location = ALLOCED_DRAM
        tensor_meta.offset = offset
        tensor_meta.been_used = false
    end

    return true
end

# Metadata update routine.
function dram_update!(tensor_meta::moDNNTensorMeta, offset, node)
    # If the offset is an integer, set the location of this tensor (implicitly, should
    # always be DRAM since we don't care about its location in PMEM)
    tensor_meta.location = ALLOCED_DRAM
    tensor_meta.been_used = true

    # An integer offset implied that this tensor had to be moved from PMEM into DRAM.
    if isnothing(offset) 
        @assert last(tensor_meta.actions).location == DRAM
        push!(last(tensor_meta.actions).consumers, node)
    else
        tensor_meta.offset = offset
        # Update the actions for this tensor_meta 
        push!(tensor_meta.actions, MoveAction([node], DRAM, false, nothing))
    end
    return nothing
end

#####
##### Offloading Scheme
#####

# TODO:
#
# Try to allocate each needed input and all outputs.
# - If one can not be allocated, try to find an offloading scheme for that tensor
# - Keep repeating until either everything is allocated, or no offloading scheme can be found
# - If no offloading scheme can be found, defrag.
function offload!(pool, meta, node, data)
    # Determine which tensors are candidates for offloading
    candidates = DataStructures.SortedDict(
        m.offset => (tensor, m) for (tensor, m) in meta
        if (m.been_used) || !(used_next(tensor, data, node))
    )

    @assert all(x -> x.offset >= 0, keys(candidates))

    # We start with the node candidates.
end

# Find a offloading scheme for size `sz`
#
# Provide an optional blacklist of offsets so we can perform multiple offloadings
# without colliding
function offloading_scheme(sz, pool, meta, node, data, blacklist = Int[])
    candidates = DataStructures.SortedDict(
        m.offset => (tensor, m) for (tensor, m) in meta
        if (m.been_used) || !(used_next(tensor, data, node)) && !in(m.offset, blacklist)
    )

    # Assert that allocation fails
    @assert isnothing(allocate(pool, sz))
    
end

function used_next(tensor, data, node)
    in(tensor, inputs(node)) || in(tensor, outputs(node)) && return true

    # Get the index of this node
    node_index = data.node_to_index[node]
    node_index == length(nodes(data)) && return false

    next_node = nodes(data, node_index + 1)
    return in(tensor, inputs(next_node))
end
