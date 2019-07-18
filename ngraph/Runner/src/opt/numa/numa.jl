mutable struct NumaTensorMeta
    tensor::TensorDescriptor
    location::TensorLocation
    offset::Int64
end

function numa(backend::nGraph.Backend, f::nGraph.NFunction, limit)
    pool = MemoryAllocator(limit, 4096)

    data = profile(f, backend)
    meta = Dict(
        # Default tensors to starting in PMEM
        t => NumaTensorMeta(t, DRAM, -1) for t in tensors(data)
    )

    for (index, node) in enumerate(nodes(data))
        # Try to allocate the outputs in the pool. If we can allocate, these tensors
        # belong in DRAM.
        #
        # Otherwise, they belong in PMEM. Simple as that.
        for tensor in filter(!_ignore, data.newlist[data.node_to_index[node]])
            offset = allocate(pool, sizeof(tensor))
            if !isnothing(offset)
                meta[tensor].location = DRAM
                meta[tensor].offset = offset
            else
                meta[tensor].location = PMEM
            end
        end

        for tensor in filter(!_ignore, data.freelist[data.node_to_index[node]])
            # Free this tensor from DRAM
            if meta[tensor].location == DRAM
                free(pool, meta[tensor].offset)
            end
        end
    end

    # Create a schedule and configure the graph
    schedule = Dict(t.tensor => (t.location, MoveAction[]) for t in values(meta))
    return data, schedule
end

function run_numa(backend, func, limit)
    fex = actualize(backend, func)
    data, schedule = numa(backend, fex.ex.ngraph_function, limit)
    fex, tesor_map = configure!(fex, data, schedule)
    return fex
end
