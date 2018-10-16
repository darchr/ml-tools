############################################################################################
# CIFAR CNN
############################################################################################
# Small CNN on cifar - used mainly for testing out infrastructure here because of its short
# training time.
struct CifarCnn <: AbstractWorkload 
    args::NamedTuple
end
CifarCnn() = CifarCnn(NamedTuple())

const cifarfile = "cifar10_cnn.py"

image(::CifarCnn) = "darchr/tf-keras:latest"
startfile(::CifarCnn, ::Type{OnHost}) = joinpath(MLTOOLS, "tf-compiled", "tf-keras", "models", cifarfile)
startfile(::CifarCnn, ::Type{OnContainer}) = joinpath("/home", "startup", cifarfile)

function runcommand(cifar::CifarCnn)
    `python3 $(startfile(cifar, OnContainer)) $(makeargs(cifar.args))`
end


function create(cifar::CifarCnn)
    bind_dataset = join([
        CIFAR_PATH,
        "/root/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")

    bind_start = join([
        dirname(startfile(cifar, OnHost)),
        dirname(startfile(cifar, OnContainer)),
    ], ":")

    
    # Create the container
    container = DockerX.create_container( 
        image(cifar);
        attachStdin = true,
        binds = [bind_dataset, bind_start],
        cmd = runcommand(cifar),
    )

    return container
end
