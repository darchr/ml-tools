#####
##### Reuse Plot
#####

struct ReusePlot end
@recipe function f(::ReusePlot, p::ProfileData)
    # Operate at a 1MiB granularity to avoid taking forever.
    pagesize = 1E6
    buckets = map(Runner.nodes(p)) do node
        pages = Set{Int}()

        for tensor in Iterators.flatten((Runner.inputs(node), Runner.outputs(node)))
            offset = floor(Int, nGraph.get_pool_offset(Runner.unwrap(tensor)) / pagesize)
            sz = sizeof(tensor)
            for i in offset:offset + ceil(Int, sz / pagesize)
                push!(pages, i)
            end
        end
        return pages
    end

    r = Runner.reuse(buckets)

    y = Runner.cdf(r.upper)
    x = collect(1:length(y))

    seriestype := :line
    xlabel := "Reuse Distance (MiB)"
    ylabel := "CDF"
    legend := :none

    @series begin
        x, y
    end
end

#####
##### Code to perform the reuse distance analsis
#####

"""
    BucketStack{T}

Like a stack, but entries in the stack are buckets of elements rather than single elements.
This models the fact that we sample active pages over an interval and don't have an exact
trace.

Fields
------
* `buckets::Vector{Set{T}}`
* `index_record::Dict{T,Int}` - Mapping of items to their index in the Stack.

Constructor
-----------

    BucketStack{T}()

Construct an empty `BucketStack` with element types `T`.
"""
struct BucketStack{T}
    buckets::Vector{Set{T}}
    index_record::Dict{T,Int}
end

BucketStack{T}() where T = BucketStack(Vector{Set{T}}(), Dict{T,Int}())

Base.length(B::BucketStack) = length(B.buckets)
Base.getindex(B::BucketStack, inds...) = getindex(B.buckets, inds...)

function Base.push!(B::BucketStack{T}, bucket::Set{T}) where {T}
    # Put this stack on the top - then go through, delete the previous occurance
    # of each item in the stack and update the index record.
    push!(B.buckets, bucket)
    new_index = length(B.buckets)
    for item in bucket
        old_index = get!(B.index_record, item, new_index)
        old_index == new_index && continue
        delete!(B.buckets[old_index], item)
        B.index_record[item] = new_index
    end
    return nothing
end

#####
##### Compute the reuse distance
#####

function reuse(buckets::Vector{Set{T}}) where {T}
    # Construct upper and lower bounds dictionaries.
    lower = Dict{Int,Int}()
    upper = Dict{Int,Int}()
    bounds = (lower = lower, upper = upper)

    # Create a new bucket stack
    stack = BucketStack{T}()

    # Do the stack analysis
    indices = Vector{Int}()
    for bucket in buckets
        empty!(indices)
        # Get the lower bound
        getlower!(bounds, stack, bucket, indices)
        push!(stack, bucket)
        # Get the upper bound now that a full union has been performed on the new bucket
        getupper!(bounds, stack, indices)
    end

    return bounds
end

"""
    increment!(d::AbstractDict, k, v)

Increment `d[k]` by `v`. If `d[k]` does not exist, initialize it to `v`.
"""
increment!(d::AbstractDict, k, v) = haskey(d, k) ? (d[k] += v) : (d[k] = v)

function getlower!(bounds::NamedTuple, stack::BucketStack, bucket, indices = Vector{Int}())
    for item in bucket
        # Check if the item has been seen before
        index = get(stack.index_record, item, nothing)

        # Item has not been seen
        if index === nothing
            increment!(bounds.lower, -1, 1)
            increment!(bounds.upper, -1, 1)

        # Item Has been seen
        else
            depth = 1
            for i in index+1:length(stack)
                if !isempty(stack[i])
                    depth += length(stack[i])
                end
            end
            increment!(bounds.lower, depth, 1)
            push!(indices, index)
        end
    end

    return indices
end

function getupper!(bounds::NamedTuple, stack::BucketStack, indices)
    for index in indices
        depth = 0
        for i in index:length(stack)
            if !isempty(stack[i])
                depth += length(stack[i])
            end
        end
        increment!(bounds.upper, depth, 1)
    end
end

#####
##### Utils
#####

function moveend!(d)
    if haskey(d, -1)
        m = maximum(keys(d))
        d[m+1] = d[-1]
        delete!(d, -1)
    end
    return nothing
end

"""
    transform(dict)

Transform a histogram `dict` into a vector representation.
"""
function transform(dict)
    ks = sort(collect(keys(dict)))

    array = Vector{valtype(dict)}()
    sizehint!(array, round(Int, last(ks) - first(ks)))

    lastkey = first(ks) - 1
    for k in ks
        # Append an appropriate number of zeros to the last
        for _ in 1:(k - lastkey - 1)
            push!(array, zero(valtype(dict)))
        end
        push!(array, dict[k])
        lastkey = k
    end
    return array
end

"""
    cdf(x) -> Vector

Return the `cdf` of `x`.
"""
function cdf(x)
    v = x ./ sum(x)
    for i in 2:length(v)
        v[i] = v[i] + v[i-1]
    end
    return v
end

function cdf(x::Dict)
    d = copy(x)
    moveend!(d)
    return cdf(transform(d))
end
