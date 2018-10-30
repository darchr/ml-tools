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
        trace, trackstack, 
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
include("models/models.jl")

# Forward function from MemSnoop
const trace = MemSnoop.trace
const trackstack = MemSnoop.trackstack

# Helper functions
isnothing(x) = false
isnothing(::Nothing) = true

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
argify(a, b::Nothing) = (dash(a),)
argify(a, b) = (dash(a), b)
makeargs(@nospecialize nt::NamedTuple) = collect(flatten(argify(a,b) for (a,b) in pairs(nt)))

############################################################################################
# Basic run command
run(work::AbstractWorkload; kw...) = run(DockerX.attach, net; kw...)

"""
    run([f::Function], work::AbstractWorkload; kw...)

Create and launch a container from `work` with
```
    container = create(work; kw...)
```
Start the container and then call `f(container)`. If `f` is not given, then attach to the
container's `stdout`.
"""
function Base.run(f::Function, work::AbstractWorkload; kw...)
    container = create(work; kw...)
    @info "Created: $container"

    # Wrap a try-finally for graceful cleanup in case something goes wrong, or someone gets
    # bored and hits ctrl+c
    DockerX.start(container)
    try 
        f(container)
    finally
        DockerX.remove(container, force = true)

        @info "Container stopped and removed"
    end
end

end # module
