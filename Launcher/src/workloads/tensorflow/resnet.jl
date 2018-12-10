"""
Struct representing parameters for launching the Tensorflow Official Resnet Model on the
Imagenet training set. Construct type using a key-word constructor

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
@with_kw struct ResnetTF <: AbstractWorkload
    args :: NamedTuple = NamedTuple()
    interactive :: Bool = false
end

image(::ResnetTF) = "darchr/tf-official-models"

_models(::Type{OnHost}) = joinpath(WORKLOADS, "tensorflow", "official")
_models(::Type{OnContainer}) = joinpath("/models", "official")

startfile(::ResnetTF, ::Type{OnContainer}) = joinpath(
    _models(OnContainer), "resnet", "imagenet_main.py"
)

function runcommand(resnet::ResnetTF)
    # Extract the arguments from the stuct
    kw = resnet.args

    # Check if the "data_dir" arg is present. If not, add it to the default location.
    if !haskey(kw, :data_dir)
        data_dir = (data_dir = "/imagenet",)
        kw = merge(kw, data_dir)
    end

    # Construct the launch comand
    if resnet.interactive
        return `/bin/bash`
    else
        return `python3 $(startfile(resnet, OnContainer)) $(makeargs(kw, "="))`
    end
end

function create(resnet::ResnetTF; kw...)
    # Bind the Imagenet dataset into the top level of the container
    bind_dataset = bind(DATASET_PATHS["imagenet_tf_official_small"], "/imagenet")

    # Attach the whole model directory.
    bind_code = bind(_models(OnHost), _models(OnContainer))

    # Create the container
    container = DockerX.create_container(
        image(resnet);
        attachStdin = true,
        binds = [bind_dataset, bind_code],
        cmd = runcommand(resnet),
        kw...
    )

    return (container,)
end

#####
##### ResnetCluster
#####

struct ResnetCluster{N} <: AbstractWorkload
    workers::NTuple{N, Tuple{ResnetTF, NamedTuple}}
end

function clusterspec(n; baseport = 5000)
    portmaps = ["127.0.0.1:$port" for port in _ports(n; base = baseport)]
    return Dict("worker" => portmaps)
end

_ports(n ;base = 5000) = base:(base + n - 1)

function create(cluster::ResnetCluster{N}) where {N}
    # Create the ClusterSpec environmental variable for each instance
    spec = clusterspec(N)
    ports = _ports(N)

    containers = map(1:N) do index
        # Create the TF_CONFIG environmental variable
        task = Dict(
            "type" => "worker",
            "index" => index - 1,
        )
        tf_config = Dict(
            "cluster" => spec, 
            "task" => task
        )

        json_string = JSON.json(tf_config)
        env = ["TF_CONFIG=$json_string"]
        port = ports[index]

        # Unpack cluster
        resnet, kw = cluster.workers[index]
        container = create(resnet;
            env = env,
            #ports = [port],
            #portBindings = [port, port],
            kw...
        )
        return first(container)
    end

    return containers
end

