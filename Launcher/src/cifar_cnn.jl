############################################################################################
# CIFAR CNN
############################################################################################
# Small CNN on cifar - used mainly for testing out infrastructure here because of its short
# training time.
struct CifarCnn <: AbstractWorkload end
const cifarfile = "cifar10_cnn.py"

image(::Type{CifarCnn}) = "darchr/tf-keras:latest"
startfile(::Type{CifarCnn}, ::Type{OnHost}) = joinpath(MLTOOLS, "tf-compiled", "tf-keras", "models", cifarfile)
startfile(::Type{CifarCnn}, ::Type{OnContainer}) = joinpath("/home", "startup", cifarfile)

runcommand(::Type{CifarCnn}) = `python3 $(startfile(CifarCnn, OnContainer))`


function create(::Type{CifarCnn})
    bind_dataset = join([
        CIFAR_PATH,
        "/root/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")

    bind_start = join([
        dirname(startfile(CifarCnn, OnHost)),
        dirname(startfile(CifarCnn, OnContainer)),
    ], ":")

    
    # Create the container
    container = DockerX.create_container( 
        image(CifarCnn);
        attachStdin = true,
        binds = [bind_dataset, bind_start],
        cmd = runcommand(CifarCnn),
    )

    return container
end
