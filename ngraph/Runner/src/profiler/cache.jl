struct EmptyCache end

Base.haskey(::EmptyCache, args...) = false
Base.setindex!(::EmptyCache, args...) = nothing

# Cache object for recording seen kernels.
struct CPUKernelParams{IS, OS, IT, OT, NIF}
    # The description of the op 
    description::String 

    # IO Sizes
    input_sizes::IS
    output_sizes::OS
    input_types::IT
    output_types::OT

    # MKLDNN Formats
    ismkl::Bool
    input_formats::NTuple{NIF, Int64} 
end

function CPUKernelParams(node::nGraph.Node)
    description = nGraph.description(node)

    # Input processing
    num_inputs = nGraph.get_input_size(node)

    input_sizes = ntuple(x -> nGraph.get_input_shape(node, x), num_inputs)
    input_types = ntuple(x -> nGraph.get_input_element_type(node, x), num_inputs)

    ismkl = nGraph.is_mkldnn(node)
    input_formats = ntuple(
        # At the moment, still forwarding to nGraph.Lib.
        x -> nGraph.Lib.get_input_format_string(node.ptr, convert(UInt, x-1)), 
        num_inputs
    )

    # output processing
    num_outputs = nGraph.get_output_size(node) 
    output_sizes = ntuple(x -> nGraph.get_output_shape(node, x), num_outputs)
    output_types = ntuple(x -> nGraph.get_output_element_type(node, x), num_outputs)

    return CPUKernelParams(
        description,
        input_sizes,
        output_sizes,
        input_types,
        output_types,
        ismkl,
        input_formats,
    )
end

# The cache itself
struct CPUKernelCache
    cache::Dict{Tuple{CPUKernelParams, IOConfig}, Float64}
end
CPUKernelCache() = CPUKernelCache(Dict{Tuple{CPUKernelParams, IOConfig},Float64}())

Base.getindex(cache::CPUKernelCache, args...) = getindex(cache.cache, args...)
Base.setindex!(cache::CPUKernelCache, args...) = setindex!(cache.cache, args...)
Base.haskey(cache::CPUKernelCache, args...) = haskey(cache.cache, args...)
