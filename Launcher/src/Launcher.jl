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
        # Trace functions
        trace, track_distance, 
        # Util Functions
        size_mb, make_cdf, memory_vec



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
using Serialization


# Add DockerX to talk to the Docker daemon.
using MemSnoop
using DockerX
using HTTP
using ProgressMeter
using JSON
using Parameters

include("utils.jl")
include("setup.jl")
include("stats.jl")
include("workloads/workloads.jl")

# Forward function from MemSnoop
const trace = MemSnoop.trace
const track_distance = MemSnoop.track_distance

standard_filter(x, size = 4) =  !(MemSnoop.executable(x)) &&
                                (MemSnoop.readable(x) || MemSnoop.writable(x)) &&
                                MemSnoop.longerthan(x, size)

standard_filter(size::Integer) = x -> standard_filter(x, size) 

# Helper functions
isnothing(x) = false
isnothing(::Nothing) = true

"""
    isrunning(container::Container) -> Bool

Return `true` if `container` is running.
"""
function isrunning(container::Container)
    # List the containers, filter on ID. Should only get one result.
    filters = Dict("id" => [DockerX.getid(container)])
    list = DockerX.list_containers(all = true, filters = filters)
    @assert length(list) == 1

    return first(list).params["State"] == "running"
end

function Base.getpid(container::Container)
    data = DockerX.inspect(container)
    return data[k"State/Pid"]
end 


dash(x) = "--$x"
argify(a, b::Nothing, delim) = dash(a)
argify(a, b, delim) = join((dash(a), b), delim)

argify(a, b::Nothing) = (dash(a),)
argify(a, b) = (dash(a), b)

makeargs(nt::NamedTuple, delim) = [argify(a,b,delim) for (a,b) in pairs(nt)]
makeargs(nt::NamedTuple) = collect(flatten(argify(a,b) for (a,b) in pairs(nt)))

############################################################################################
# Basic run command
Base.run(workload::AbstractWorkload; kw...) = run(DockerX.attach, workload; kw...)

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

Examples
--------
Using Julia's `do` syntax to perform a stack based analysis

```julia
tracker = run(TestWorkload()) do container
    trackstack(getpid(container))
end
```
"""
function Base.run(f::Function, work::AbstractWorkload; showlog = false, kw...)
    container = create(work; kw...)
    @info "Created: $container"

    # Wrap a try-finally for graceful cleanup in case something goes wrong, or someone gets
    # bored and hits ctrl+c
    DockerX.start(container)
    try 
        f(container)
    finally
        showlog && println(DockerX.log(container))

        DockerX.remove(container, force = true)

        @info "Container stopped and removed"
    end
end

end # module
