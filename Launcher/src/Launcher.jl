module Launcher

export Resnet


# Set up some static things
if Base.Sys.isapple()
    const CIFAR_PATH = "/Users/mark/projects/ml-tools/cifar-10-batches-py.tar.gz"
else
    const CIFAR_PATH = "/data1/ml-datasets/cifar-10-batches-py.tar.gz"
end

# Add DockerX to talk to the Docker Daemon.
using DockerX
using HTTP
using ProgressMeter

abstract type AbstractWorkload end

struct Resnet <: AbstractWorkload end

image(::Type{Resnet}) = "hildebrandmw/tf-resnet:latest"
function create(::Type{Resnet})
    # Attach the cifar dataset at /data1 to the keras cache 
    bind_dataset = join([
            CIFAR_PATH,
            "/root/.keras/datasets/cifar-10-batches-py.tar.gz"
        ], ":")

    # Create the container
    container = DockerX.create_container( 
        image(Resnet);
        attachStdin = true,
        binds = [bind_dataset],
        cmd = `python3 /home/cifar10_resnet.py`,
    )

    return container
end

"""
    run_resnet(time)

Run `tf-resnet` for the specified amount of time.
"""
function Base.run(::Type{Resnet}, runtime)
    # Start the Docker proxy
    DockerX.runproxy() 

    container = create(Resnet)

    @info "Created: $container"

    try 
        DockerX.start(container)
        @showprogress for i in 1:runtime
            sleep(1)
        end
        log = DockerX.log(container)
        println(log)

    finally
        DockerX.stop(container)
        DockerX.remove(container)
        DockerX.killproxy()

        @info "Container stopped and removed"
    end
    return nothing
end


end # module
