############################################################################################
# RESNET
############################################################################################
"""
Struct representing parameters for launching Resnet on the Cifar training set.

Fields
------
* `args` - Arguments passed to the Keras Python script that creates and trains Resnet.
* `interactive` - Set to `true` to create a container that does not automatically run
    Resnet when launched. Useful for debugging what's going on inside the container.
* `memory::Union{Nothing, Int}` - The amount of memory to assign to this container. If
    this value is `nothing`, the container will have access to all system memory.
* `cpus::Union{Nothing, Int}` - Limit the number of cpus available to this container.
    If `nothing`, the container can use all available cpus.
"""
@with_kw struct Resnet <: AbstractWorkload
    args :: NamedTuple              = NamedTuple()
    interactive :: Bool             = false
    memory :: Union{Nothing, Int}   = nothing
    cpus :: Union{Nothing, Int}     = nothing
end

# Setup parameters
const resnetfile = "cifar10_resnet.py"
image(::Resnet) = "darchr/tf-keras:latest"

startfile(::Resnet, ::Type{OnHost}) = joinpath(
    MLTOOLS, "tf-compiled", "tf-keras", "models", resnetfile
)

startfile(::Resnet, ::Type{OnContainer}) = joinpath("/home", "startup", resnetfile)
function runcommand(resnet::Resnet)
    if resnet.interactive
        `/bin/bash`
    else
        `python3 $(startfile(resnet, OnContainer))`
    end
end


function create(resnet::Resnet; memory = nothing, cpus = nothing)
    # Attach the cifar dataset at /data1 to the keras cache
    # Need to put the dataset into the cache expected by Keras in order to avoid Keras
    # automatically downloading the dataset. That's why the path
    #
    # /tmp/.keras/datasets/cifar...
    #
    # is so specific. Also, since we are no longer running as root, have to put the keras
    # directory in /tmp
    bind_dataset = join([
        DATASET_PATHS["cifar"],
        "/home/user/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")

    bind_start = join([
        dirname(startfile(resnet, OnHost)),
        dirname(startfile(resnet, OnContainer)),
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
        image(resnet);
        attachStdin = true,
        binds = [bind_dataset, bind_start],
        cmd = runcommand(resnet),
        kw...
    )

    return container
end
