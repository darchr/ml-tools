# Taken from https://github.com/hildebrandmw/Consecutive.jl
import Base: iterate, IteratorSize, IteratorEltype

macro ifsomething(ex)
    return quote
        result = $(esc(ex))
        result === nothing && return nothing
        result
    end
end

struct ConsecIter{I}
    xs::I
end

"""
    consecutive(xs)
Return an iterator that returns consecutive elements of `xs`.
```jldoctest
julia> a = 1:2:11
1:2:11
julia> collect(consecutive(a))
5-element Array{Tuple{Int64,Int64},1}:
 (1, 3)
 (3, 5)
 (5, 7)
 (7, 9)
 (9, 11)
```
"""
consecutive(i) = ConsecIter(i)

function iterate(it::ConsecIter)
    first, state = @ifsomething iterate(it.xs)
    second, state = @ifsomething iterate(it.xs, state)

    return ((first, second), (second, state))
end


function iterate(it::ConsecIter, s::Tuple)
    first, state = s
    second, state = @ifsomething iterate(it.xs, state)

    return ((first, second), (second, state))
end

restrict(x) = x
restrict(::Base.HasShape) = Base.HasLength()

# Forwards
Base.length(it::ConsecIter) = length(it.xs) - 1
Base.eltype(it::ConsecIter) = Tuple{eltype(it.xs),eltype(it.xs)}

# Shape gets destroyed when doing consecutive iteration. Since "HasLength()" is "weaker"
# than HasShape, restrict HasShape to HasLength. Pass everhthing else through.
IteratorSize(::ConsecIter{I}) where {I} = restrict(IteratorSize(I))
IteratorEltype(::ConsecIter{I}) where {I} = IteratorEltype(I)
