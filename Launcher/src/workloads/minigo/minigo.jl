@with_kw struct Minigo <: AbstractWorkload
    args::NamedTuple = NamedTuple()
end

image(::Minigo) = "darchr/reinforcement"

function runcommand(minigo::Minigo)
    return `./run_and_time_skx_8180_2s_1x.sh`
end

function create(
        minigo::Minigo; 
        env = [],
        kmp_blocktime = 1,
        kmp_settings = 1,
        omp_num_threads = 48,
        kw...)

    # Extend the provided environmental
    localenv = [
        "LOCAL_USER_ID=$(uid())",
    ]
    env = vcat(env, localenv)

    container = create_container(
        TensorflowMKL();
        attachStdin = true,
        cmd = runcommand(minigo),
        env = env,
        kw...
    )

    return container
end
