@with_kw struct Inception <: AbstractWorkload
    args::NamedTuple = NamedTuple()
    interactive::Bool = false
end

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

    # The original source for the incepetion code is from a TPU model - so for now, we
    # need to shut down any attempt to run the TPU specific code.
    if !haskey(kw, :use_tpu)
        kw = merge(kw, (use_tpu = false,))
    end

    # Environment variables for MKL

    if model.interactive
        return `/bin/bash`
    else
        return `python3 $(startfile(model, OnContainer)) $(makeargs(kw; delim = "="))`
    end
end

function create(model::Inception; kw...)
    bind_dataset = bind(DATASET_PATHS["imagenet_tf_slim"], "/imagenet")
    bind_code = bind(code(OnHost), code(OnContainer))

    env = [
        "KMP_BLOCKTIME=1",
        "KMP_AFFINITY=granularity=fine,compact,1,0",
        "KMP_SETTINGS=1",
        "OMP_NUM_THREADS=48",
        "LOCAL_USER_ID=$(uid())",
    ]

    @show runcommand(model)

    container = Docker.create_container(
        image(model),
        attachStdin = true,
        binds = [bind_dataset, bind_code],
        cmd = runcommand(model),
        env = env,
        kw...
    )
end
