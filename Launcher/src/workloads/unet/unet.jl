@with_kw struct Unet <: AbstractWorkload
    args::NamedTuple = NamedTuple()
    interactive::Bool = false
end

image(::Unet) = "darchr/3dunet"

code(::Unet, ::Type{OnHost}) = joinpath(WORKLOADS, "3dUnet", "src")
code(::Unet, ::Type{OnContainer}) = joinpath("/brats_repo")

function runcommand(model::Unet) 
    if model.interactive
        return `/bin/bash`
    else
        return `python3 /brats_repo/brats/train_isensee2017.py $(makeargs(model.args))`
    end
end

function create(
        model::Unet;
        env = [],
        kmp_blocktime = 1, 
        kmp_settings = 1,
        omp_num_threads = 48,
        kw...
       )

    # Bind the dataset directory into the "brats" folder of the brats repo
    bind_dataset = bind(
        DATASET_PATHS["brats"],
        joinpath("/brats_repo", "brats", "data")
    )

    bind_code = bind(
        code(model, OnHost),
        code(model, OnContainer),
    )

    @show bind_code

    localenv = [
        "KMP_BLOCKTIME=$kmp_blocktime",
        "KMP_AFFINITY=granularity=fine,compact,1,0",
        "KMP_SETTINGS=$kmp_settings",
        "OMP_NUM_THREADS=$omp_num_threads",
        "LOCAL_USER_ID=$(uid())",
    ]
    env = vcat(env, localenv)

    @show runcommand(model)

    container = Docker.create_container(image(model);
        binds = [bind_code, bind_dataset],
        cmd = runcommand(model),
        env = env,
        kw...
    )
end
