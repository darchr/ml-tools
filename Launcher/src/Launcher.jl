module Launcher

function __init__()
    # Set up the paths to datasets
    setup()
end

import Base.Iterators: flatten, drop, product
import Base.iterate

export  k_str, create_setup,
        # Models
        Resnet,
        CifarCnn,
        # Util Functions
        size_mb, memory_vec, subsample


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
using SystemSnoop
using ProgressMeter
using JSON
using Parameters

include("utils.jl")
include("setup.jl")
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


end # module
