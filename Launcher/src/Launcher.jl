module Launcher

export Resnet, CifarCnn

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const MLTOOLS = dirname(PKGDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

const LOG_PATH = joinpath(DEPSDIR, "logs")
const SCRIPT_PATH = joinpath(DEPSDIR, "scripts")

# Set up some static things
if Base.Sys.isapple()
    const CIFAR_PATH = "/Users/mark/projects/ml-tools/cifar-10-batches-py.tar.gz"
else
    const CIFAR_PATH = "/data1/ml-datasets/cifar-10-batches-py.tar.gz"
end


# Add DockerX to talk to the Docker daemon.
using DockerX
using HTTP
using ProgressMeter
using JSON

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

function collectstats(container::Container; sleepinterval = 0)
    # Check if the container is running.
    stats = [] 
    while isrunning(container)
        push!(stats, DockerX.stats(container))
        if sleepinterval > 0
            sleep(sleepinterval)
        end
    end
    return stats
end


# Location information. Specify whether paths are supposed to be on the host computer or
# on the container.
abstract type Location end
struct OnHost <: Location end
struct OnContainer <: Location end

## Workloads
abstract type AbstractWorkload end

startfile(::Type{T}, ::Type{L}) where {T <: AbstractWorkload, L <: Location} = error("""
    Startfile not defined for workload type $T on location $L
    """)

runcommand(::Type{T}) where T = `$(startfile(T, OnContainer))`

############################################################################################
# Basic run command
function Base.run(::Type{T}; interval = 10, logio = devnull) where T <: AbstractWorkload
    container = create(T)
    local stats

    @info "Created: $container"

    # Wrap a try-finally for graceful cleanup in case something goes wrong, or someone gets
    # bored and hits ctrl+c
    try 
        DockerX.start(container)

        # Run until the epoch finishes.
        stats = collectstats(container; sleepinterval = interval)

        print(logio, DockerX.log(container))
    finally
        DockerX.remove(container, force = true)

        @info "Container stopped and removed"
    end
    return stats
end


# Include files - TODO: Move these to a more resonable location instead of at the bottom
# of this file. That's dumb.
include("cifar_cnn.jl")
include("cifar_resnet.jl")

end # module
