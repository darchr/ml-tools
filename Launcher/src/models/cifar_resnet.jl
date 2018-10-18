############################################################################################
# RESNET
############################################################################################
struct Resnet <: AbstractWorkload end

const resnetfile = "cifar10_resnet.py"

image(::Type{Resnet}) = "darchr/tf-keras:latest"
startfile(::Type{Resnet}, ::Type{OnHost}) = joinpath(
    MLTOOLS, "tf-compiled", "tf-keras", "models", resnetfile
)

startfile(::Type{Resnet}, ::Type{OnContainer}) = joinpath("/home", "startup", resnetfile)
runcommand(::Type{Resnet}) = `python3 $(startfile(Resnet, OnContainer))`

function create(::Type{Resnet}; memory = nothing, cpus = nothing)
    # Attach the cifar dataset at /data1 to the keras cache 
    # Need to put the dataset into the cache expected by Keras in order to avoid Keras
    # automatically downloading the dataset. That's why the path
    #
    # /tmp/.keras/datasets/cifar...
    # 
    # is so specific. Also, since we are no longer running as root, have to put the keras
    # directory in /tmp
    bind_dataset = join([
        CIFAR_PATH,
        "/tmp/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")

    bind_start = join([
        dirname(startfile(Resnet, OnHost)),
        dirname(startfile(Resnet, OnContainer)),
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
        binds = [bind_dataset, bind_start],
        cmd = runcommand(Resnet),
        kw...
    )

    return container
end
