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
    corr = Dict{Any,Any}()
    for t in unique(targets)
        for (key, v) in f(samples)
            for _v in unique(v)
                p_v = count(isequal(_v), v)
                p_v_and_t = count(x -> first(x) == t && last(x) == _v, zip(targets, v))

                corr[(t,_v)] = p_v_and_t / p_v
            end 
        end
    end

    return corr
end

