############################################################################################
# CIFAR CNN
############################################################################################
# Small CNN on cifar - used mainly for testing out infrastructure here because of its short
# training time.
"""
Workload object for the Keras Cifar10 cnn. Build type using keyword constructors.

Fields
------
* `args :: NamedTuple` - Arguments to pass to the startup script (see docs). 
    Default: `NamedTuple()`
* `interactive :: Bool` - If set to true, the container will launch into `/bin/bash`
    instead of Python. Used for debugging the container. Default: `false`.

[`create`](@ref) keywords
-----------------

* `cpuSets = ""` - The CPU sets on which to run the workload. Defaults to all processors. 
    Examples: `"0"`, `"0-3"`, `"1,3"`.
"""
@with_kw struct CifarCnn <: AbstractWorkload 
    args :: NamedTuple    = NamedTuple()
    interactive :: Bool   = false
end

const cifarfile = "cifar10_cnn.py"

image(::CifarCnn) = "darchr/tf-compiled-base"
startfile(::CifarCnn, ::Type{OnHost}) = joinpath(WORKLOADS, "keras", cifarfile)
startfile(::CifarCnn, ::Type{OnContainer}) = joinpath("/home", "startup", cifarfile)

function runcommand(cifar::CifarCnn)
    if cifar.interactive
        return `/bin/bash`
    else
        return `python3 $(startfile(cifar, OnContainer)) $(makeargs(cifar.args))`
    end
end

function create(cifar::CifarCnn; cpuSets = "", kw...)
    bind_dataset = join([
        DATASET_PATHS["cifar"]
        "/home/user/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")

    bind_start = join([
        dirname(startfile(cifar, OnHost)),
        dirname(startfile(cifar, OnContainer)),
    ], ":")

    # Create the container
    container = Docker.create_container( 
        image(cifar);
        attachStdin = true,
        binds = [bind_dataset, bind_start],
        cmd = runcommand(cifar),
        env = ["LOCAL_USER_ID=$(uid())"],
        cpuSets = cpuSets
    )

    return container
end
