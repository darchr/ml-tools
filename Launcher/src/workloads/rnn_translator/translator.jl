"""
Workload object for the RNN Translator, built using keyword constructors.

Fields
------
* `args :: NamedTuple` - Arguments to pass to the startup script (see docs). 
    Default: `NamedTuple()`
* `interactive :: Bool` - If set to true, the container will launch into `/bin/bash`
    instead of Python. Used for debugging the container. Default: `false`.
"""
@with_kw struct Translator <: AbstractWorkload
    args :: NamedTuple = NamedTuple()
    interactive :: Bool = false
end

function runcommand(rnn::Translator) 
    # Extract the arguments from the stuct
    kw = rnn.args 

    # Add the "no-cuda" flag if needed 
    if !haskey(kw, :no___cuda)
        nocuda = (no___cuda = nothing,)
        kw = merge(kw, nocuda)
    end

    # Setup default save and data dirs
    if !haskey(kw, :save)
        kw = merge(kw, (save = "gnmt_wmt16", ))
    end

    if !haskey(kw, :dataset___dir)
        kw = merge(kw, (dataset___dir = "/data",))
    end

    # Construct the launch comand
    if rnn.interactive 
        return `/bin/bash` 
    else
        return `python3 /workspace/pytorch/train.py $(makeargs(kw; delim = "="))`
    end
end

function create(
        rnn::Translator; 
        env = [],
        kmp_blocktime = 1,
        kmp_settings = 1,
        omp_num_threads = 24,
        kw...)
    # Bind the Imagenet dataset into the top level of the container
    bind_dataset = bind(
        joinpath(DATASET_PATHS["rnn_translator"], "data"),
        "/data"
    )

    # Extend the provided environmental
    localenv = [
        "LOCAL_USER_ID=$(uid())",
    ]
    env = vcat(env, localenv)

    container = create_container(
        GNMT();
        attachStdin = true,
        binds = [bind_dataset],
        cmd = runcommand(rnn),
        env = env,
        kw...
    )

    return container
end

"""
    Launcher.translator_parser(file::String) -> Float64

Return the mean time per step from an output log file for the [`Launcher.Translator`](@ref)
workload.
"""
translator_parser(file::String) = open(translator_parser, file)
function translator_parser(io::IO)
    seekstart(io)

    times = Float64[]
    float_regex = r"[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?"
    for ln in eachline(io)
        if all(x -> occursin(x, ln), ("TRAIN", "Time", "Data", "Tok/s"))
            runtime = collect(eachmatch(float_regex, ln))[5]
            push!(times, parse(Float64, runtime.match))
        end
    end
    return mean(times)
end
