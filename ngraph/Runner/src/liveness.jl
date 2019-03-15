mutable struct TensorRecordFactory
    count::Int64
end

struct TensorRecord
    # An unique ID for this tensor
    id::Int64

    # The number of bytes in this tensor
    size::Int64

    # A descriptor that should be unique for each tensor
    #
    # Used to determine if a tensor has already been created.
    descriptor::nGraph.TensorDescriptor
end

function TensorRecord(T::TensorRecordFactory, size, pointer)
    T.count += 1
    return TensorRecord(T.count - 1, size, pointer)
end

# General procedure for doing liveness analysis - we do a forward pass through the ordered
# ops, 
