module Launcher

export Resnet

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


## Workloads
abstract type AbstractWorkload end

startfile(::Type{T}) where T <: AbstractWorkload = error("""
    Startfile not defined for workload type $T
    """)

function modelbind(::Type{T}) where T <: AbstractWorkload
    # Get the path here.
    localpath = startfile(T) 
    localdir = dirname(localpath)

    remotepath = "/home/startup/$(basename(localpath))" 
    remotedir = dirname(remotepath)
    return "$localdir:$remotedir"
end

############################################################################################
# CIFAR CNN
############################################################################################
# Small CNN on cifar - used mainly for testing out infrastructure here because of its short
# training time.
struct CifarCnn <: AbstractWorkload end
image(::Type{CifarCnn}) = "darchr/tf-keras:latest"
startfile(::Type{CifarCnn}) = joinpath(MLTOOLS, "tf-compiled", "tf-keras", "models", "cifar10_cnn.py")

function create(::Type{CifarCnn})
    bind_dataset = join([
        CIFAR_PATH,
        "/root/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")


    
    # Create the container
    container = DockerX.create_container( 
        image(CifarCnn);
        attachStdin = true,
        binds = [bind_dataset],
        cmd = `python3 /home/cifar10_cnn.py`,
    )

    return container
end

############################################################################################
# RESNET
############################################################################################
struct Resnet <: AbstractWorkload end

image(::Type{Resnet}) = "darchr/tf-keras:latest"

function create(::Type{Resnet}; memory = nothing, cpus = nothing)
    # Attach the cifar dataset at /data1 to the keras cache 
    # Need to put the dataset into the cache expected by Keras in order to avoid Keras
    # automatically downloading the dataset. That's why the path
    #
    # /root/.keras/datasets/cifar...
    # 
    # is so specific.
    bind_dataset = join([
        CIFAR_PATH,
        "/root/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")
    
    ## Decode keyword arguments.
    # Strategy: Build up a named tuple. Only add fields if the corresponding keyword 
    # arguments are supplied.
    kw = NamedTuple() 

    # CPU - Ratio of cpuQuota over cpuPeriod approximately gives the number of CPUs 
    # available for work.
    #
    # TODO: Once amarillo quiets down, mayby switch this over to assigning processors 
    # directly to avoid the container getting scheduled all over the place.
    if !isnothing(cpus)
        # cpu units in Microseconds - set the default period to 1 second.
        cpuPeriod = 1000000
        cpuQuota = cpus * cpuPeriod
        kw = merge(kw, (cpuPeriod = cpuPeriod, cpuQuota = cpuQuota))
    end

    if !isnothing(memory)
        kw = merge(kw, (Memory = memory,))
    end

    # Create the container
    container = DockerX.create_container( 
        image(Resnet);
        attachStdin = true,
        binds = [bind_dataset],
        cmd = `python3 /home/cifar10_resnet.py`,
        kw...
    )

    return container
end

"""
    run(::Resnet, time)

Run `tf-resnet` for the specified amount of time.
"""
function Base.run(::Type{T}; interval = 10, logio = devnull) where T <: AbstractWorkload
    # Start the Docker proxy
    DockerX.runproxy() 

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
        DockerX.killproxy()

        @info "Container stopped and removed"
    end
    return stats
end


end # module
