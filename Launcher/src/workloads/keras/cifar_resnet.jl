############################################################################################
# RESNET
############################################################################################
"""
Struct representing parameters for launching ResnetKeras on the Cifar training set.
Construct type using a key-word constructor

Fields
------
* `args::NamedTuple` - Arguments passed to the Keras Python script that creates and 
    trains Resnet.

* `interactive::Bool` - Set to `true` to create a container that does not automatically run
    Resnet when launched. Useful for debugging what's going on inside the container.

[`create`](@ref) keywords
-------------------------
* `memory::Union{Nothing, Int}` - The amount of memory to assign to this container. If
    this value is `nothing`, the container will have access to all system memory.
    Default: `nothing`.

* `cpuSets = ""` - The CPU sets on which to run the workload. Defaults to all processors. 
    Examples: `"0"`, `"0-3"`, `"1,3"`.
"""
@with_kw struct ResnetKeras <: AbstractWorkload
    args :: NamedTuple              = NamedTuple()
    interactive :: Bool             = false
end

# Setup parameters
const resnetfile = "cifar10_resnet.py"
image(::ResnetKeras) = "darchr/tf-keras:latest"

startfile(::ResnetKeras, ::Type{OnHost}) = joinpath(WORKLOADS, "keras", resnetfile)
startfile(::ResnetKeras, ::Type{OnContainer}) = joinpath("/home", "startup", resnetfile)
function runcommand(resnet::ResnetKeras)
    if resnet.interactive
        `/bin/bash`
    else
        `python3 $(startfile(resnet, OnContainer))`
    end
end


function create(resnet::ResnetKeras; memory = nothing, cpuSets = "")
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

    if !isnothing(memory)
        kw = merge(kw, (Memory = memory,))
    end

    # Create the container
    container = DockerX.create_container(
        image(resnet);
        attachStdin = true,
        binds = [bind_dataset, bind_start],
        cmd = runcommand(resnet),
        cpuSets = cpuSets,
        kw...
    )

    return container
end
