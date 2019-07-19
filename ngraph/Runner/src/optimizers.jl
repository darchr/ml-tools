#####
##### Convenience Wrappers around routines
#####

function titlename end

## Static ILP Formulation
struct Static
    # PMM to DRAM ratio
    ratio::Rational{Int}
end

name(::Static) = "static"
function (M::Static)(data)
    bounds = Runner.allocation_bounds(data)

    x = fill(round(Int, (bounds.upper_bound / (M.ratio + 1)) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.static(x; defrag = !iszero(M.ratio.num))
end

## Synchronous ILP Formulation
struct Synchronous
    ratio::Rational{Int}
end

name(::Synchronous) = "synchronous"
function (M::Synchronous)(data)
    bounds = Runner.allocation_bounds(data)
    x = fill(round(Int, (bounds.upper_bound / (M.ratio + 1)) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.synchronous(x, 29000, 12000; defrag = !iszero(M.ratio.num))
end

## Asynchronous ILP Formulation
struct Asynchronous
    ratio::Rational{Int}
end

name(::Asynchronous) = "asynchronous"
function (M::Asynchronous)(data)
    bounds = Runner.allocation_bounds(data)
    x = fill(round(Int, (bounds.upper_bound / (M.ratio + 1)) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.asynchronous(x, 29000, 12000, 2000, 2500; defrag = !iszero(M.ratio.num))
end

## Numa formulation
struct Numa
    ratio::Rational{Int}
end

name(::Numa) = "numa"
function (M::Numa)(data)
    bounds = Runner.allocation_bounds(data)
    x = round(Int, (bounds.upper_bound / (M.ratio + 1)))
    println("Trying to use $(maximum(x)) MB of memory")

    # Return the result as Bytes without scaling to MB
    return x
end
