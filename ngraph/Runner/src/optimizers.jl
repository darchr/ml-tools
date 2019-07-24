#####
##### Convenience Wrappers around routines
#####

const OPTIM_TYPES = Union{Int64, Rational{Int64}}

"""
    AbstractOptimizer{T} where {T <: Union{Int64, Rational{Int64}}}

An `AbstractOptimizer` is used to dispatch to various backend optimization routines like
static, synchronous, asynchronous, and others.

The type parameter encodes some of the high level behavior:

* `Int64`: The limit supplied by the type is an absolute memory limit.

* `Rational{Int64}`: The limit supplied by the type is a ratio of Large Memory (i.e. PMEM)
    to Limited Memory (i.e. DRAM)

    This will dispatch to another routine that will perform a grid search on the ratio to
    find an input ratio to supply that will result in an actual output ratio closest to
    the original input.
"""
abstract type AbstractOptimizer{T <: OPTIM_TYPES} end
abstract type ILPOptimizer{T} <: AbstractOptimizer{T} end

const BANDWIDTHS = (
    # Split out CPU based on cases.
    cpu_pmem_dram_sync = 29000,
    cpu_dram_pmem_sync = 12000,
    cpu_pmem_dram_async = 2000,
    cpu_dram_pmem_async = 2500,

    # GPU Basically same in all diractions
    gpu = 12000
)

_bw_remote_local_sync(::nGraph.Backend{nGraph.CPU}) = BANDWIDTHS[:cpu_pmem_dram_sync]
_bw_local_remote_sync(::nGraph.Backend{nGraph.CPU}) = BANDWIDTHS[:cpu_dram_pmem_sync]
_bw_remote_local_async(::nGraph.Backend{nGraph.CPU}) = BANDWIDTHS[:cpu_pmem_dram_async]
_bw_local_remote_async(::nGraph.Backend{nGraph.CPU}) = BANDWIDTHS[:cpu_dram_pmem_async]

_bw_remote_local_sync(::nGraph.Backend{nGraph.GPU}) = BANDWIDTHS[:gpu]
_bw_local_remote_sync(::nGraph.Backend{nGraph.GPU}) = BANDWIDTHS[:gpu]
_bw_remote_local_async(::nGraph.Backend{nGraph.GPU}) = BANDWIDTHS[:gpu]
_bw_local_remote_async(::nGraph.Backend{nGraph.GPU}) = BANDWIDTHS[:gpu]

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

getratio(x::AbstractOptimizer{Rational{Int64}}) = x.ratio
getratio(x::Number) = x

getlimit(x::AbstractOptimizer{Int64}) = x.ratio

_optimizer(::T, r) where {T <: AbstractOptimizer} = T(r)

_numerator(x::AbstractOptimizer{Rational{Int64}}) = getratio(x).num
_numerator(x::AbstractOptimizer{Int64}) = getlimit(x)

_denominator(x::AbstractOptimizer{Rational{Int64}}) = getratio(x).den
_denominator(x::AbstractOptimizer{Int64}) = one(Int64)

## Static ILP Formulation
struct Static{T} <: ILPOptimizer{T}
    # PMM to DRAM ratio
    ratio::T

    # We use inner constructors to avoid automitic promotion to rationals or ints which
    # could lead to subtle bugs.
    Static{T}(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
    Static(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
end

name(::Static) = "static"
function (M::Static{Rational{Int64}})(data, backend::nGraph.Backend)
    bounds = Runner.allocation_bounds(data)

    x = fill(round(Int, (bounds.upper_bound / (getratio(M) + 1)) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.static(x; defrag = !iszero(_numerator(M)))
end

function (M::Static{Int64})(data, backend::nGraph.Backend)
    x = fill(round(Int, getlimit(M) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.static(x)
end


## Synchronous ILP Formulation
struct Synchronous{T} <: ILPOptimizer{T}
    ratio::T
    Synchronous{T}(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
    Synchronous(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
end

name(::Synchronous) = "synchronous"
function (M::Synchronous{Rational{Int}})(data, backend::nGraph.Backend)
    bounds = Runner.allocation_bounds(data)
    x = fill(
        round(Int, (bounds.upper_bound / (getratio(M) + 1)) / 1E6), size(Runner.nodes(data))
    )
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.synchronous(x,
                              _bw_remote_local_sync(backend),
                              _bw_local_remote_sync(backend);
                              defrag = !iszero(_numerator(M))
                             )
end

function (M::Synchronous{Int})(data, backend::nGraph.Backend)
    x = fill(round(Int, getlimit(M) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.synchronous(x,
                              _bw_remote_local_sync(backend),
                              _bw_local_remote_sync(backend);
                              defrag = !iszero(_numerator(M))
                             )
end


## Asynchronous ILP Formulation
struct Asynchronous{T} <: ILPOptimizer{T}
    ratio::T

    Asynchronous{T}(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
    Asynchronous(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
end

name(::Asynchronous) = "asynchronous"
function (M::Asynchronous{Rational{Int}})(data, backend::nGraph.Backend)
    bounds = Runner.allocation_bounds(data)
    x = fill(round(Int, (bounds.upper_bound / (getratio(M) + 1)) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.asynchronous(x,
                              _bw_remote_local_sync(backend),
                              _bw_local_remote_sync(backend),
                              _bw_remote_local_async(backend),
                              _bw_local_remote_async(backend);
                              defrag = !iszero(_numerator(M))
                              )
end

function (M::Asynchronous{Int})(data, backend::nGraph.Backend)
    x = fill(round(Int, getlimit(M) / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.asynchronous(x, 
                              _bw_remote_local_sync(backend),
                              _bw_local_remote_sync(backend),
                              _bw_remote_local_async(backend),
                              _bw_local_remote_async(backend);
                              defrag = !iszero(_numerator(M))
                             )
end


## Numa formulation
struct Numa{T} <: AbstractOptimizer{T}
    ratio::T

    Numa{T}(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
    Numa(x::T) where {T <: OPTIM_TYPES} = new{T}(x)
end

name(::Numa) = "numa"
function (M::Numa{Rational{Int64}})(data, backend::nGraph.Backend)
    bounds = Runner.allocation_bounds(data)
    x = round(Int, (bounds.upper_bound / (M.ratio + 1)))
    println("Trying to use $(x) MB of memory")

    # Return the result as Bytes without scaling to MB
    return x
end

function (M::Numa{Int64})(data, backend::nGraph.Backend)
    x = getlimit(M)
    println("Trying to use $(x) MB of memory")

    # Return the result as Bytes without scaling to MB
    return x
end
