module Launcher

function __init__()
    # Set up the paths to datasets
    setup()
end

import Base.Iterators: flatten, drop

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

# Add DockerX to talk to the Docker daemon.
using DockerX
using HTTP
using ProgressMeter
using JSON
using Parameters

include("stats.jl")
include("utils.jl")
include("setup.jl")
include("workloads/workloads.jl")

############################################################################################
# Basic run command
_attach(x::DockerX.Container) = DockerX.attach(x)
_attach(x) = DockerX.attach(first(x))
Base.run(workload::AbstractWorkload; kw...) = run(_attach, workload; kw...)

"""
    run([f::Function], work::AbstractWorkload; showlog = false, kw...)

Create and launch a container from `work` with

```julia
container = create(work; kw...)
```

Start the container and then call `f(container)`. If `f` is not given, then attach to the
container's `stdout`.

This function ensures that containers are stopped and cleaned up in case something goes wrong.

If `showlog = true`, send the container's log to `stdout` when the container stops.
"""
function Base.run(f::Function, work::AbstractWorkload; showlog = false, kw...)
    # If "create" only returns a single container, wrap it in a tuple so the broadcasted
    # methods below work seamlessly
    containers = create(work; kw...)
    @info "Created: $containers"

    # Wrap a try-finally for graceful cleanup in case something goes wrong, or someone gets
    # bored and hits ctrl+c
    DockerX.start.(_wrap(containers))
    try
        f(containers)
    finally
        if showlog
            for container in _wrap(containers)
                @info "Showing Log for Container $container"
                println(DockerX.log(container))
            end
        end

        DockerX.remove.(_wrap(containers), force = true)

        @info "Containers stopped and removed"
    end
end
_wrap(x::DockerX.Container) = (x,)
_wrap(x) = x

end # module
