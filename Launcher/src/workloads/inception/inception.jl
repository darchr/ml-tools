@with_kw struct Inception <: AbstractWorkload
    args::NamedTuple = NamedTuple()
    interactive::Bool = false
end

include("cluster.jl")

image(::Inception) = "darchr/tf-compiled-base"

code(::Type{OnHost}) = joinpath(WORKLOADS, "inception", "src")
code(::Type{OnContainer}) = joinpath("/models", "inception")

startfile(::Inception, ::Type{T}) where {T} = joinpath(code(T), "inception_v4.py")

function runcommand(model::Inception)
    kw = model.args

    # Check for data_dir in arguments, default it to /imagenet
    if !haskey(kw, :data_dir)
        kw = merge(kw, (data_dir = "/imagenet",))
    end

    if model.interactive
        return `/bin/bash`
    else
        return `python3 $(startfile(model, OnContainer)) $(makeargs(kw; delim = "="))`
    end
end

function create(
        model::Inception; 
        env = [], 
        kmp_blocktime = 1, 
        kmp_settings = 1,
        omp_num_threads = 48,
        kw...
    )
    bind_dataset = bind(DATASET_PATHS["imagenet_tf_slim"], "/imagenet")
    bind_code = bind(code(OnHost), code(OnContainer))

    # Extend the provided environmental
    localenv = [
        "KMP_BLOCKTIME=$kmp_blocktime",
        "KMP_AFFINITY=granularity=fine,compact,1,0",
        "KMP_SETTINGS=$kmp_settings",
        "OMP_NUM_THREADS=$omp_num_threads",
        "LOCAL_USER_ID=$(uid())",
    ]
    env = vcat(env, localenv)

    container = Docker.create_container(image(model);
        binds = [bind_dataset, bind_code],
        cmd = runcommand(model),
        env = env,
        kw...
    )
end

#####
##### Setup for creating a cluster
#####

# I could make this type stable, but I don't think there's much of a point...
struct InceptionCluster <: AbstractWorkload
    workers::Vector
end
Base.length(T::InceptionCluster) = length(T.workers)

_ports(n, base) = base:(base + n - 1)
function clusterspec(n, base)
    portmaps = ["127.0.0.1:$port" for port in _ports(n, base)]
    return Dict("worker" => portmaps)
end

function create(cluster::InceptionCluster; base = 5000)
    # Create the ClusterSpec environmental variable for each instance.
    spec = clusterspec(length(cluster), base)
    ports = _ports(length(cluster), base)

    containers = map(1:length(cluster)) do index
        # Create the TF_Config environmental variable
        task = Dict(
            "type" => "worker",
            "index" => index - 1,
        )
        tf_config = Dict(
            "cluster" => spec,
            "task" => task,
        )
        json_string = JSON.json(tf_config)

        env = [
            "TF_CONFIG=$json_string",
        ]

        # Unpack worker and create container
        worker, kw = cluster.workers[index]
        container = create(worker; env = env, kw...)

        return container
    end

    return containers
end

# Check to see if this line matches the the printout for the time per step.
#
# An example line looks like this:
#
# I0125 15:02:43.353371 140087033124608 tf_logging.py:115] loss = 11.300481, step = 2 (10.912 sec)
#
# This is a very brutal strategy, but we'll look for the key words "loss", "step" and "sec".
#
# If those all match, we'll match for a float and take the last item.
function tf_timeparser(io::IO)
    seekstart(io)

    times = Float64[]
    float_regex = r"[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?"
    for ln in eachline(io)
        if all(x -> occursin(x, ln), ("loss", "step", "sec"))
            runtime = last(collect(eachmatch(float_regex, ln)))
            push!(times, parse(Float64, runtime.match))
        end
    end
    return mean(times)
end
tf_timeparser(path::String) = open(tf_timeparser, path)
