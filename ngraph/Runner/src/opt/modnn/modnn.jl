include("allocator.jl")

@enum IntermediateTensorLocation UNALLOC ALLOCED_DRAM ALLOCED_PMEM

mutable struct moDNNTensorMeta
    tensor::TensorDescriptor

    # Current location
    location::IntermediateTensorLocation

    # If current location is in DRAM, this offset points to the allocation offset
    offset::Int64

    # Flag to indicate if this tensor has been used since its last prefetch or generation
    been_used::Bool

    actions::Vector{MoveAction}
end

_ignore(t::String) = any(startswith.(Ref(t), ("Parameter", "Result", "Constant")))
_ignore(t::TensorDescriptor) = _ignore(nGraph.name(t))

xinputs(node::NodeDescriptor) = filter(!_ignore, inputs(node))
xoutputs(node::NodeDescriptor) = filter(!_ignore, outputs(node))


# Implementation of the moDNN algorithm, adjusted for the PMM/DRAM case.
function schedule(fex::nGraph.FluxExecutable, data::ProfileData, limit)
    # T is the current time
    T = 0

    # Initilize tensor metadata for each tensor
    meta = Dict(
        t => moDNNTensorMeta(t, UNALLOC, -1, false, MoveAction[]) for t in tensors(data)
    )
    pool = MemoryAllocator(limit, 4096)

    # Iterate through the nodes in the graph in topological order
    for (index, node) in enumerate(nodes(data))
        println("Processing Node $index of $(length(nodes(data)))")

        # try to allocate. If allocation fails, find an offloading scheme
        # (which may cause defragmentation)
        #
        # Then try to reallocate
        if !(allocate_io!(pool, meta, node))
            offload!(pool, meta, node, data)
        end

        # Free any unused tensors
        for tensor in data.freelist[data.node_to_index[node]]
            tensor_meta = meta[tensor]
            free(pool, tensor_meta.offset)

            # Clean up this tensor
            tensor_meta.offset = -1
            tensor_meta.location = UNALLOC
        end
    end

    return meta
end

#####
##### Tensor IO Allocation
#####

function allocate_io!(pool, meta, node)
    # Check the location of all inputs to the node in DRAM. If not, try to allocate space
    # for them.
    input_offsets = Dict(
        t => allocate(pool, sizeof(t)) for t in xinputs(node)
        if meta[t].location != ALLOCED_DRAM
    )

    # If any of the input allocations failed, free anything we allocated are return `false`.
    if any(isnothing, values(input_offsets))
        @show collect(values(input_offsets))
        @show sizeof.(keys(input_offsets))

        free.(Ref(pool), values(input_offsets))
        return false
    end

    # We've successfully allocated inputs, try to allocate the outputs
    output_offsets = Dict(t => allocate(pool, sizeof(t)) for t in xoutputs(node))
    if any(isnothing, values(output_offsets))
        @show collect(values(input_offsets))
        @show sizeof.(keys(input_offsets))

        @show collect(values(output_offsets))
        @show sizeof.(keys(output_offsets))

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

function move_to_pmm!(tensor_meta::moDNNTensorMeta, node, data)
    tensor_meta.location = ALLOCED_PMEM
    tensor_meta.been_used = false

    # Check if this tensor has been moved into PMEM before. If so, don't do anything.
    # Otherwise, we have to emit the initial MoveAction
    if !any(x -> x.location == PMEM, tensor_meta.actions)
        # This node might not a user of this tensor, so we make all future users of this
        # tensor a consumer of the move
        node_index = data.node_to_index[node]
        users = _users(tensor_meta.tensor, data)

        # @show node_index
        # @show [data.node_to_index[x] for x in users]
        # @show tensor_meta.tensor

        ind = something(findfirst(x -> data.node_to_index[x] >= node_index, users))
        push!(tensor_meta.actions, MoveAction(users[ind:end], PMEM, true, nothing))
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
    # Go through all the inputs that need to be allocated and all the outputs.
    # Gather offloading schemes for each.
    #
    # If an offloading scheme cannot be found for input and output tensors, emit a defrag.
    offsets = Int[]
    alloced_offsets = Int[]
    defrag = false
    
    for tensor in xinputs(node)
        tensor_meta = meta[tensor]
        if tensor_meta.location != ALLOCED_DRAM
            # See if we can just straight up allocate this tensor
            offset = allocate(pool, sizeof(tensor))
            if !isnothing(offset)
                push!(alloced_offsets, offset)
                continue
            end

            scheme = offloading_scheme(sizeof(tensor), pool, meta, node, data, offsets)
            # Offloading failed, need to defrag
            if isnothing(scheme)
                defrag = true
                break
            end

            @info "Input Scheme: $scheme"

            # Keep a running tally of all the offsets to offload.
            # This is forwarded to the blacklist of `offloading_scheme` so we don't try to
            # offload the same offset multiple times.
            append!(offsets, scheme)
        end
    end

    # Handle outputs in a similar fashion.
    #
    # No need to check if an output is already allocated ... because it shouldn't be.
    if !defrag
        for tensor in xoutputs(node)
            offset = allocate(pool, sizeof(tensor))
            if !isnothing(offset)
                push!(alloced_offsets, offset)
                continue
            end


            tensor_meta = meta[tensor]
            scheme = offloading_scheme(sizeof(tensor), pool, meta, node, data, offsets)
            if isnothing(scheme)
                defrag = true
                break
            end

            @info "Output Scheme: $scheme"
            append!(offsets, scheme)
        end
    end

    # Free up all the temporary alloced offsets
    for offset in alloced_offsets 
        free(pool, offset)
    end

    # If we have to defrag, replace the offsets with all of the tensors currently in the pool.
    if defrag
        @info "Defragging!"
        empty!(offsets)
        for tensor_meta in values(meta)
            if tensor_meta.location == ALLOCED_DRAM
                push!(offsets, tensor_meta.offset)
            end
        end
    end

    # Handle the offloading from offsets - updating the MoveActions of tensor metadatas
    offset_map = Dict(m.offset => m for m in values(meta) if m.location == ALLOCED_DRAM)
    for offset in filter(o -> haskey(offset_map, o), offsets)
        tensor_meta = offset_map[offset]
        @info """
        Offloading $offset
        Size: $(sizeof(tensor_meta.tensor))
        """

        free(pool, offset)
        move_to_pmm!(tensor_meta, node, data)
    end

    if defrag
        @assert length(pool.node_list) == 1
    end

    # Allocate inputs and outputs
    @info "Free Nodes before Allcation: " showfree(pool)
    @assert allocate_io!(pool, meta, node)
    @info "Free Nodes after Allcation: " showfree(pool)

    return nothing
end

# Find a offloading scheme for size `sz`
#
# Provide an optional blacklist of offsets so we can perform multiple offloadings
# without colliding
function offloading_scheme(
        sz,
        pool::MemoryAllocator,
        meta,
        node::NodeDescriptor,
        data::ProfileData,
        blacklist = Int[]
    )

    candidates = DataStructures.SortedDict(
        m.offset => (tensor, m) for (tensor, m) in meta
        if (m.been_used) && 
            !(used_next(tensor, data, node)) && 
            !in(m.offset, blacklist) &&
            (m.location == ALLOCED_DRAM)
    )

    # Assert that allocation fails
    if !all(x -> x >= 0, keys(candidates))
        @error candidates
    end
    @assert isnothing(allocate(pool, sz))

    # Iterate through all the blocks in the pool.
    schemes = Vector{Int}[]
    partial_schemes = Vector{Int}[]
    delete_indices = Int[]

    # Helper functions
    _scheme_size(scheme::Vector, node) = last(scheme) - first(scheme) + sizeof(node)
    _canuse(memory_node, offset) = isfree(memory_node) || haskey(candidates, offset)

    offset = 0
    for memory_node in pool.node_list
        if _canuse(memory_node, offset)
            # Add this offset to each partisl scheme
            push!.(partial_schemes, offset)

            # Create a new partisl scheme starting at this offset
            push!(partial_schemes, [offset])
        else
            # Hit a dead block - purge all partial schemes
            empty!(partial_schemes)
        end

        # If any of the partial schemes can hold an allocation of this size,
        # emit it into the set of actual schemes
        empty!(delete_indices)
        for (index, scheme) in enumerate(partial_schemes)
            if _scheme_size(scheme, memory_node) >= sz
                push!(schemes, scheme)
                push!(delete_indices, index)
            end
        end
        deleteat!(partial_schemes, delete_indices)

        # Update offset
        offset += sizeof(memory_node)
    end

    # If no offloading schemes are found, return nothing
    isempty(schemes) && return nothing

    # Otherwise, find the scheme that requires the least offloading and return that.
    best_offloading = typemax(Int)
    best_scheme = Int[]
    for scheme in schemes
        # Compute the total size of tensors to offload
        #
        # Because the scheme has a mixture of free and allocated blocks, we skip over the
        # already free blocks when performing this calculation.
        offload_size = sum(
            sizeof(first(candidates[o])) for o in scheme if haskey(candidates, o)
        )

        if offload_size < best_offloading
            best_offloading = offload_size
            best_scheme = scheme
        end
    end

    @show best_offloading

    return best_scheme
end

function used_next(tensor, data::ProfileData, node)
    (in(tensor, xinputs(node)) || in(tensor, xoutputs(node))) && return true

    # Get the index of this node
    node_index = data.node_to_index[node]
    node_index == length(nodes(data)) && return false

    next_node = nodes(data, node_index + 1)
    return in(tensor, xinputs(next_node))
end
