# Module for looking at conditional probabilities of variables.
#
# The goal is to collect many variables from the assignments of tensors to DRAM/PMEM and
# move nodes, find correlations between these data points and the assignemnt, and
# automatically spit out anything that looks significant.
function correlation(targets::Dict, samples::Dict)
    for (k,v) in targets
        _correlation(v, samples)
    end
end

function pair_pairs(d::Dict, ::Val{N}) where N
    # Collect keys and values to avoid any ordering issues
    ks = collect(keys(d))
    vs = [d[k] for k in ks]

    a = Iterators.product(ntuple(i -> ks[i:N], N)...)
    b = (zip(ntuple(i -> d[x[i]], N)...) for x in a)

    return zip(a, b)
end

correlation(target::Vector, samples) = correlation(pairs, target, samples)
function correlation(f, targets::Vector, samples)
    # Do some pre-couting on the samples
    cache = Dict(k => Dict(v => count(isequal(v), samples[k]) for v in unique(samples[k])) for k in keys(samples))

    # We're doing the computation
    #
    # P(B|A) = P(A ∩ B) / P(A)
    #
    # This is the super simple implementation of count all the occurances of something
    # and dividing bythe total number of occurances
    #
    # Right now, it's only performing a single correlation. But, I can imagine wrapping
    # the events as anonymous functions and being able to perform arbitrarily complex
    # checks for conditional probability.
    corr = Dict{Any,Tuple{Float64,Int64}}()
    for t in unique(targets)
        for (key, v) in f(samples)
            for _v in unique(v)
                p_v = cache[key][_v]
                p_v_and_t = count(x -> first(x) == t && last(x) == _v, zip(targets, v))

                corr[(t,(key => _v))] = (p_v_and_t / p_v, p_v_and_t)
            end
        end
    end

    return corr
end

#####
##### Correlation Analysis
#####
function correlation_analysis(fex::nGraph.FluxExecutable, frame, metadata; 
        threshold = 0.8, 
        min_count = 10
    )
    data = frame.profile_data

    # Find the unique kernel types
    descriptions = unique(nGraph.description.(fex.ex.ngraph_function))

    # Now, we begin building metadata for each kind of profile.
    #
    # For each kernel type, gather a bunch of metadata about the kernel, such as
    # - input sizes
    # Then gather all the input and output tensor, populate metadata about the tensors
    # and try to draw conclusions

    all_kernels = collect(fex.ex.ngraph_function)
    for desc in filter(hasprofile, descriptions)
        features = Dict{String,Vector}()
        targets = Dict{String,Vector}()

        # Get all the kerels that fit this description
        kernels = filter(x -> nGraph.description(x) == desc, all_kernels)
        for kernel in kernels
            for (index, tensor) in enumerate(inputs(kernel))
                add_data!(targets, features, tensor, kernel, :input, index, data, metadata)
            end
            for (index, tensor) in enumerate(outputs(kernel))
                add_data!(targets, features, tensor, kernel, :output, index, data, metadata)
            end
        end

        # Print information
        println("Processing Correlations for $desc")
        println("Number of kernels: $(length(kernels))")
        for (k,v) in targets
            println()
            println("Target Feature: $k")
            corr = correlation(v, features)

            # Filter out results that "aren't significant"
            filtered_corr = Dict(
                k => v 
                for (k,v) in corr 
                if first(v) >= threshold && last(v) >= min_count)
            display(filtered_corr)
        end
        println()
        println()
    end
end

dict_push!(d, k, v) = haskey(d, k) ? push!(d[k], v) : (d[k] = [v])

function add_data!(targets, features, tensor, kernel, io_type, io_index, data, tensor_map)
    ### Add Targets
    # Add if this tensor in in DRAM or PMEM
    dict_push!(targets, "Location", nGraph.is_persistent(tensor) ? PMEM : DRAM)
       
    # Get the parent of this node.
    parent = getparent(tensor_map, tensor)

    # Add the number of move nodes for this tensor
    dict_push!(targets, "Num Moves", length(getchildren(tensor_map, parent )))

    ### Add Features
    # Add the size of the tensor
    #dict_push!(features, "Tensor Size", sizeof(tensor))

    # Add the lifespan of the tensor
    # Divide by some factor to break these into buckets
    quantizing_factor = 100
    producing_index = div(data.node_to_index[_producer(tensor, data)], quantizing_factor)
    dict_push!(features, "Parent Index", producing_index)

    consumers = vcat(
        _consumer(parent, data), 
        _consumer.(getchildren(tensor_map, parent), Ref(data))
    )
    consumer_index = div(maximum(data.node_to_index[n] for n in consumers), quantizing_factor)
    dict_push!(features, "Life Span", consumer_index - producing_index)

    # Add the shape of the tensor
    # if io_type == :input
    #     dict_push!(features, "Tensor Shape", string(size(tensor)))
    # else
    #     dict_push!(features, "Tensor Shape", string(size(tensor)))
    # end

    # Add which input / output this is
    dict_push!(features, "IO Kind", "$io_type $io_index")

    # Add the input and output sizes for this kernel
    #for (index, input) in enumerate(inputs(kernel))
    #    dict_push!(features, "Kernel Input $index shape", string(size(input)))
    #end
    #for (index, output) in enumerate(outputs(kernel))
    #    dict_push!(features, "Kernel Output $index shape", string(size(output)))
    #end
end


