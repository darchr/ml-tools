module Launcher

import Base.Iterators: flatten, drop

export k_str, Resnet, CifarCnn

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

## STDLIB
using Dates


# Add DockerX to talk to the Docker daemon.
using DockerX
using HTTP
using ProgressMeter
using JSON

include("stats.jl")
include("wss.jl")
include("reref.jl")
include("models/models.jl")

"""
    currentuser() -> String

Return a string formatted for the current unix User and Group.
"""
function currentuser()
    uid = (chomp ∘ read)(`id -u`, String)
    gid = (chomp ∘ read)(`id -g`, String)
    return "$uid:$gid"
end

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
makeargs(@nospecialize nt::NamedTuple) = collect(flatten((dash(a),b) for (a,b) in pairs(nt)))


############################################################################################
# Basic run command
function Base.run(net::AbstractWorkload; interval = 10, logio = devnull)
    container = create(net)
    local pages

    @info "Created: $container"

    # Wrap a try-finally for graceful cleanup in case something goes wrong, or someone gets
    # bored and hits ctrl+c
    try 
        DockerX.start(container)

        # Run until the epoch finishes.
        pages = monitor(getpid(container); sleeptime = interval) 
        # @sync begin 
        #     @async docker_stats = getstats(container; sleepinterval = interval)
        #     @async rereference = monitor_reref(getpid(container); sleepinterval = interval)
        # end

        print(logio, DockerX.log(container))
    catch err
        print(stdout, DockerX.log(container))
        @error "Error" err
    finally
        DockerX.remove(container, force = true)

        @info "Container stopped and removed"
    end
    return pages
end

end # module
