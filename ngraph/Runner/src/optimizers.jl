#####
##### Convenience Wrappers around routines
#####

abstract type AbstractOptimizer end

function titlename end

# Bound on the actual between requested ratio for a workload.
#
# We iterate on the solution untill the ratio of PMEM to DRAM is within this bound of
# the requested ratio.
const RATIO_TOLERANCE = Ref(0.05)

function checkmargin(actual, wanted, tol = RATIO_TOLERANCE[])
    # Handle the cases where the denominator of "wanted" is zero
    rwanted, ractual = getratio.((wanted, actual))  

    if iszero(rwanted.den) || iszero(rwanted.num)
        return true
    else
        return abs(ractual / rwanted - 1) <= tol
    end
end

geterr(actual, wanted) = abs(getratio(actual) / getratio(wanted) - 1)

getratio(x::AbstractOptimizer) = x.ratio
getratio(x::Number) = x

_optimizer(::T, r) where {T <: AbstractOptimizer} = T(r)

## Static ILP Formulation
struct Static <: AbstractOptimizer
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
struct Synchronous <: AbstractOptimizer
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
struct Asynchronous <: AbstractOptimizer
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
struct Numa <: AbstractOptimizer
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
