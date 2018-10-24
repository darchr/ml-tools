module Launcher

function __init__()
    # Set up the paths to datasets
    setup()
end

import Base.Iterators: flatten, drop

export k_str, Resnet, CifarCnn, create_setup

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


# Add DockerX to talk to the Docker daemon.
using MemSnoop
using DockerX
using HTTP
using ProgressMeter
using JSON

include("setup.jl")
include("stats.jl")
#include("reref.jl")
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
    @ssert length(list) == 1

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
function Base.run(net::AbstractWorkload; interval = 5, logio = devnull)
    container = create(net)
    local stack

    @info "Created: $container"

    # Wrap a try-finally for graceful cleanup in case something goes wrong, or someone gets
    # bored and hits ctrl+c
    try 
        DockerX.start(container)

        @show getpid(container)

        # Sleep for a little bit - let everything start up.
        #sleep(5)
        #stack = MemSnoop.trackstack(getpid(container); sampletime = interval)
        @sync begin
            @async stack = MemSnoop.trackstack(getpid(container); sampletime = interval)
            @async DockerX.attach(container)
        end

        print(logio, DockerX.log(container))
    catch err
        print(stdout, DockerX.log(container))
        @error "Error" err
    finally
        DockerX.remove(container, force = true)

        @info "Container stopped and removed"
    end
    return stack
end

end # module
