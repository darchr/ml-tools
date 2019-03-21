function liveness_analysis(fn::nGraph.NFunction)
    new_list = [Set{nGraph.TensorDescriptor}() for _ in fn]
    free_list = [Set{nGraph.TensorDescriptor}() for _ in fn]
    for (index, op) in enumerate(fn)
        # Add all new tensors seen this 
        for descriptor in nGraph.output_descriptors(op)
            push!(new_list[index], descriptor)
        end
    end

    freed_tensors = Set{nGraph.TensorDescriptor}()
    # On the backward pass, once we see a tensor is referenced, we delete all future
    # references to that tensor since that will be the last time that tensor is used.
    for (index, op) in enumerate(reverse(fn))
        # Add all newly seen input tensors to the free list
        for descriptor in nGraph.input_descriptors(op)
            if !in(descriptor, freed_tensors)
                push!(free_list[length(fn) + 1 - index], descriptor)
            end
        end
    end

    return (new_list = new_list, free_list = free_list)
end

