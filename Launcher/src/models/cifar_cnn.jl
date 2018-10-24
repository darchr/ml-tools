############################################################################################
# CIFAR CNN
############################################################################################
# Small CNN on cifar - used mainly for testing out infrastructure here because of its short
# training time.
struct CifarCnn <: AbstractWorkload 
    args::NamedTuple
    interactive::Bool
end
CifarCnn(;
    args = NamedTuple(),
    interactive = false
   ) = CifarCnn(args, interactive)

const cifarfile = "cifar10_cnn.py"

image(::CifarCnn) = "darchr/tf-keras:latest"
startfile(::CifarCnn, ::Type{OnHost}) = joinpath(MLTOOLS, "tf-compiled", "tf-keras", "models", cifarfile)
startfile(::CifarCnn, ::Type{OnContainer}) = joinpath("/home", "startup", cifarfile)

function runcommand(cifar::CifarCnn)
    if cifar.interactive
        return `/bin/bash`
    else
        return `python3 $(startfile(cifar, OnContainer)) $(makeargs(cifar.args))`
    end
end


function create(cifar::CifarCnn)
    bind_dataset = join([
        DATASET_PATHS["cifar"]
        "/home/user/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")

    bind_start = join([
        dirname(startfile(cifar, OnHost)),
        dirname(startfile(cifar, OnContainer)),
    ], ":")

    
    # Create the container
    container = DockerX.create_container( 
        image(cifar);
        attachStdin = true,
        #user = currentuser(),
        binds = [bind_dataset, bind_start],
        cmd = runcommand(cifar),
    )

    return container
end
