module Launcher

export Resnet

# Add DockerX to talk to the Docker Daemon.
using DockerX
using ProgressMeter

abstract type AbstractWorkload end

struct Resnet <: AbstractWorkload end

image(::Type{Resnet}) = "hildebrandmw/tf-resnet:latest"
function create(::Type{Resnet})
    # Attach the cifar dataset at /data1 to the keras cache 
    bind_dataset = join([
            "/data1/ml-datasets/cifar-10-batches-py.tar.gz",
            "/root/.keras/datasets/cifar-10-batches-py.tar.gz"
        ], ":")

    # Create the container
    container = DockerX.create_container( 
        image(Resnet);
        binds = [bind_dataset],
        cmd = `python3 /home/cifar10_resnet.py`,
    )

    return container
end
"""
    run_resnet(time)

Run `tf-resnet` for the specified amount of time.
"""
function Base.run(::Type{Resnet}, time)
    # Start the Docker proxy
    DockerX.runproxy() 

    container = create(Resnet)
    id = container["Id"]

    @info "Container ID: $id"

    try 
        DockerX.start_container(id)
        @showprogress for _ in 1:time
            sleep(1)
        end

        # Open a stream to the containers log
        log = DockerX.get_log(id)
        println.(eachline(IOBuffer(log)))
    finally
        DockerX.stop_container(id)
        DockerX.remove_container(id)
        DockerX.killproxy()

        @info "Container stopped and removed"
    end
    return nothing
end


end # module
