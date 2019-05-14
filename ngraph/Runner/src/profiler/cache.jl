struct EmptyCache end

Base.haskey(::EmptyCache, args...) = false
Base.setindex!(::EmptyCache, args...) = nothing
save(::EmptyCache) = nothing

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

# For
filter_out_io(c::CPUKernelParams) = (
    c.description,
    c.ismkl,
    c.input_formats,
    c.input_types,
    c.output_types
)

mkldnn_string(x) = last(split(nGraph.Lib.get_mkldnn_string(x), ":"))

function CPUKernelParams(node::nGraph.Node)
    description = nGraph.description(node)

    # Input processing
    num_inputs = nGraph.get_input_size(node)

    input_sizes = ntuple(x -> nGraph.get_input_shape(node, x), num_inputs)
    input_types = ntuple(x -> nGraph.get_input_element_type(node, x), num_inputs)

    # Only
    ismkl = nGraph.is_mkldnn(node)
    input_formats = ntuple(
        # At the moment, still forwarding to nGraph.Lib.
        x -> nGraph.Lib.get_input_format_int(node.ptr, convert(UInt, x-1)),
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
    file::String
    cache::Dict{Tuple{CPUKernelParams, IOConfig}, Float64}
end
function CPUKernelCache(file)::CPUKernelCache
    # If the cache path already exists, just return the existing object.
    # The type assertion for the function will make sure we don't return something weird.
    if ispath(file)
        cache = deserialize(file)::CPUKernelCache
        if cache.file == file
            return cache
        end
        error("Cache Corruption.")
    end

    # Otherwise, create the object.
    return CPUKernelCache(
        file,
        Dict{Tuple{CPUKernelParams, IOConfig},Float64}()
    )
end

Base.getindex(cache::CPUKernelCache, args...) = getindex(cache.cache, args...)
Base.setindex!(cache::CPUKernelCache, args...) = setindex!(cache.cache, args...)
Base.haskey(cache::CPUKernelCache, args...) = haskey(cache.cache, args...)

function save(cache::CPUKernelCache)
    # Make the directory for this cache if needed.
    dir = dirname(cache.file)
    ispath(dir) || mkdir(dir)
    serialize(cache.file, cache)
end

unsafe_load_cache(file) = deserialize(file)

# Methods for working with and filtering caches.
nt_filter(nt::NamedTuple, cache::CPUKernelCache) = nt_filter(nt, cache.cache)
function nt_filter(nt::NamedTuple, cache::Dict)
    param_config = collect(keys(cache)) 
    filter!(x -> all(getfield(first(x), k) == v for (k,v) in pairs(nt)), param_config)
    return Dict(k => cache[k] for k in param_config)
end

function _filter(nt::NamedTuple, cache::Dict)
    k = unique(first.(collect(keys(cache))))
    filter!(x -> all(getfield(x, k) == v for (k,v) in pairs(nt)), k)
    return k
end

function choices(cache::CPUKernelCache, sym::Symbol, nt::NamedTuple = NamedTuple())
    # Iterate through the keys in the cache.
    k = _filter(nt, cache.cache)
    return unique(getfield.(k, sym))
end

#####
##### Orthogonality of kernels
#####

function check_orthogonality(cache::CPUKernelCache)
    all_keys = keys(cache.cache)
    # Get all the unique configurations
    ks = unique(first.(all_keys))

    for k in ks
        check_orthogonality(cache, all_keys, k)
    end
end

function check_orthogonality(cache::CPUKernelCache, all_keys, param)
    # Get all of the configurations
    configs = sort(unique(last.(filter(x -> first(x) == param, all_keys))))

    # Find the basis elements
    basis = make_basis(eltype(configs)) 
    base_runtime = get_base_runtime(cache.cache, param, eltype(configs))

    # Run through each config. Decompose it into a basis, get the expected running time
    # from the linear combination of basis elements, and compare to the actual result.
    for config in configs
        runtime = cache.cache[(param, config)]

        logical_index = decompose(config)
        elements = basis[logical_index]

        linear_runtime = base_runtime
        if !isempty(elements)
            linear_runtime += sum(cache.cache[(param, x)] - base_runtime for x in elements)
        end

        @show length(elements)
        @show linear_runtime
        @show runtime
    end
end

function get_base_runtime(cache::Dict, param, ::Type{IOConfig{N,M}}) where {N,M}
    return cache[(param, IOConfig(ntuple(x -> DRAM, N), ntuple(x -> DRAM, M)))]
end

function make_basis(::Type{IOConfig{N,M}}) where {N,M}
    basis = IOConfig{N,M}[]
    # Generate a basis element - check if it is in the list of configs.
    # If so, add it to the list of basis
    for i in 1:N
        inputs = ntuple(x -> x == i ? PMEM : DRAM, N)
        outputs = ntuple(x -> DRAM, M)
        push!(basis, IOConfig{N,M}(inputs, outputs))
    end
    for j in 1:M
        inputs = ntuple(x -> DRAM, N)
        outputs = ntuple(x -> x == j ? PMEM : DRAM, M)
        push!(basis, IOConfig{N,M}(inputs, outputs))
    end
    return basis
end

# Return the basis indices
decompose(config::IOConfig) = [x == PMEM ? true : false for x in config]
