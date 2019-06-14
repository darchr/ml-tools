module Launcher

function __init__()
    # Set up the paths to datasets
    setup()
end

import Base.Iterators: flatten, drop, product
import Base.iterate
import Base.Meta: quot

export TFBenchmark, Translator, Inception, CifarCnn, Unet

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const MLTOOLS = dirname(PKGDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

# Path to the setup JSON file.
const SETUP_PATH = joinpath(PKGDIR, "setup.json")

# Location of datasets - initialized in __init__()
const DATASET_PATHS = Dict{String,String}()

## STDLIBs
using Dates
using InteractiveUtils
using Serialization
using Statistics

# Add Docker to talk to the Docker daemon.
using Docker
using ProgressMeter
using JSON
using Parameters
using Glob

include("utils.jl")
include("setup.jl")
include("docker.jl")
include("workloads/workloads.jl")

############################################################################################
# Basic run command
_attach(x::Docker.Container) = Docker.attach(x)
_attach(x) = Docker.attach(first(x))
Base.run(workload::AbstractWorkload; kw...) = run(_attach, workload; kw...)

"""
    run([f::Function], work::AbstractWorkload; log::IO = devnull, kw...)

Create and launch a container from `work` with

```julia
container = create(work; kw...)
```

Start the container and then call `f(container)`. If `f` is not given, then attach to the
container's `stdout`.

This function ensures that containers are stopped and cleaned up in case something goes wrong.

After the container is stopped, write the log to IO

# Keyword Arguments

Extra keyword arguments will be forwarded to the `Docker.create`. With these arguments, it 
is possible to contstrain the resources available to the container. Standard arguments valid
across all workloads are shown below:

* `user::String`: The name of the user to run the container as. Default: "" (Root)

* `entryPoint::String` : The entry point for the container as a string or an array of 
    strings.  

    If the array consists of exactly one empty string ([""]) then the entry point is reset 
    to system default (i.e., the entry point used by docker when there is no ENTRYPOINT 
    instruction in the Dockerfile)

    Default: ""

* `memory::Integer`: Memory limit in bytes. Default: 0 (unlimited)

* `cpuSets::String`: CPUs in which to allow execution (e.g., 0-3, 0,1). Default: All CPUs

* `cpuMems::String`: Memory nodes (MEMs) in which to allow execution (0-3, 0,1). Only 
    effective on NUMA systems. Default: All NUMA nodea.

* `env::Vector{String}`: A list of environment variables to set inside the container in the 
    form ["VAR=value", ...]. A variable without = is removed from the environment, rather 
    than to have an empty value. Default: []

    **NOTE**: Some workloads (especially those working with MKL) may automatically specify 
    some environmental variables. Consult the documentation for those workloads to see
    which are specified.
"""
function Base.run(f::Function, work::AbstractWorkload; log = devnull, kw...)
    # If "create" only returns a single container, wrap it in a tuple so the broadcasted
    # methods below work seamlessly
    containers = create(work; kw...)
    @info "Created: $containers"

    # Wrap a try-finally for graceful cleanup in case something goes wrong, or someone gets
    # bored and hits ctrl+c
    Docker.start.(_wrap(containers))
    try
        f(containers)
    finally
        for (index, container) in enumerate(_wrap(containers))
            _writelog(log, container; first = (index == 1))
        end
        Docker.remove.(_wrap(containers), force = true)

        @info "Containers stopped and removed"
    end
end
_wrap(x::Docker.Container) = (x,)
_wrap(x) = x

function _writelog(io::IO, container; kw...) 
    print(io, "Showing log for $container\n")
    print(io, Docker.log(container))
end
_writelog(file::String, container; first = false)  = open(io -> _writelog(io, container), file; write = true, append = !first)


#####
##### Support for multiple simultaneous workoads
#####

"""
Wrapper type for launching multiple workloads at the same time through the [`run`](@ref)
command.
"""
struct Bundle{T <: Tuple} <: AbstractWorkload
    workloads::T
end

"""
    Bundle(workloads...) -> Bundle

Wrap the `workloads` into a single type the will launch all workloads under [`run`](@ref)

Usage is as follows:
```
bundle = Bundle(workloadA, workloadB)

run(bundle)
```
Any keywords passed to `run` will be forwarded to each workload wrapped in `bundle`.

To log the output of these workloads, see [`BundleLogger`](@ref).
"""
Bundle(args...) = Bundle(args)

# Forward create to all the wrapped workloads
create(bundle::Bundle; kw...) = map(x -> create(x; kw...), bundle.workloads)

mutable struct BundleLogger{N} 
    # Logs for each container
    logs::NTuple{N,IOBuffer}
    # Count which logs have been collected.
    count::Int
end

"""
BundleLogger(bundle::Bundle) -> BundleLogger

Create a `BundleLogger` from `bundle` to pass to the `log` keyword argument of 
[`run`](@ref). This will store the logs for each container in `bundle` sequentially
which can later be accessed by `getindex`. Example usage is shown below.

```
bundle = Bundle(workA, workB, workC)

logger = BundleLogger(bundle)

run(bundle; log = logger)

# After completion, logs can get accessed via
log1 = logger[1]

log2 = logger[2]

log3 = logger[3]
```
"""
BundleLogger(bundle::Bundle) = BundleLogger(ntuple(x -> IOBuffer(), length(bundle.workloads)), 1)
function _writelog(logger::BundleLogger, args...; kw...)
    _writelog(logger.logs[logger.count], args...; kw...)
    logger.count += 1
end

Base.getindex(logger::BundleLogger, i) = logger.logs[i]

end # module
