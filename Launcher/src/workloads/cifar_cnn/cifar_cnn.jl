"""
Workload object for the Keras Cifar10 cnn. Build type using keyword constructors.

Fields
------
* `args :: NamedTuple` - Arguments to pass to the startup script (see docs). 
    Default: `NamedTuple()`
* `interactive :: Bool` - If set to true, the container will launch into `/bin/bash`
    instead of Python. Used for debugging the container. Default: `false`.
"""
@with_kw struct CifarCnn <: AbstractWorkload 
    args :: NamedTuple    = NamedTuple()
    interactive :: Bool   = false
end

const cifarfile = "cifar10_cnn.py"

startfile(::CifarCnn, ::Type{OnHost}) = joinpath(WORKLOADS, "cifar_cnn", "src", cifarfile)
startfile(::CifarCnn, ::Type{OnContainer}) = joinpath("/home", "startup", cifarfile)

function runcommand(cifar::CifarCnn)
    if cifar.interactive
        return `/bin/bash`
    else
        return `python3 $(startfile(cifar, OnContainer)) $(makeargs(cifar.args))`
    end
end

function create(cifar::CifarCnn; kw...)
    bind_dataset = join([
        DATASET_PATHS["cifar"]
        joinpath("/root", ".keras", "datasets")
    ], ":")

    bind_start = join([
        dirname(startfile(cifar, OnHost)),
        dirname(startfile(cifar, OnContainer)),
    ], ":")

    # Create the container
    container = create_container( 
        TensorflowMKL;
        binds = [bind_dataset, bind_start],
        cmd = runcommand(cifar),
        env = ["LOCAL_USER_ID=$(uid())"],
        kw...
    )

    return container
end
