module Launcher

export Resnet

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

const LOG_PATH = joinpath(DEPSDIR, "logs")
const SCRIPT_PATH = joinpath(DEPSDIR, "scripts")

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

image(::Type{Resnet}) = "darchr/tf-resnet:latest"
startscript(::Type{Resnet}; kw...) = """
#!/bin/bash
collectl -scCdDmMZ -i 1 -R 60s -f /syslog/log &
python3 /home/cifar10_resnet.py
"""

function create(::Type{Resnet})
    # Attach the cifar dataset at /data1 to the keras cache 
    # Need to put the dataset into the cache expected by Keras in order to avoid Keras
    # automatically downloading the dataset. That's why the path
    #
    # /root/.keras/datasets/cifar...
    # 
    # is so specific.
    bind_dataset = join([
        CIFAR_PATH,
        "/root/.keras/datasets/cifar-10-batches-py.tar.gz"
    ], ":")
    
    # Attach log path to get the collectl output log
    bind_logs = join([
        LOG_PATH,
        "/syslog/"
    ], ":")

    bind_startup = join([
        SCRIPT_PATH,
        "/startup/",
    ], ":")

    # Create start script
    filepath = joinpath(SCRIPT_PATH, "resnet.sh") 
    open(filepath, "w") do f
        print(f, startscript(Resnet))
    end
    chmod(filepath, 0o777)

    # Create the container
    container = DockerX.create_container( 
        image(Resnet);
        attachStdin = true,
        binds = [bind_dataset, bind_logs, bind_startup],
        cmd = `/startup/resnet.sh`,
        # cpuPeriod = 1000000,
        # cpuQuota = 1000000,
    )

    return container
end

"""
    run(::Resnet, time)

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
