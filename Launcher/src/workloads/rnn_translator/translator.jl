@with_kw struct Translator <: AbstractWorkload
    args :: NamedTuple = NamedTuple()
    interactive :: Bool = false
end

image(::Translator) = "gnmt:latest"

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


function create(rnn::Translator; kw...)
    # Bind the Imagenet dataset into the top level of the container
    bind_dataset = bind(
        joinpath(DATASET_PATHS["rnn_translator"], "data"),
        "/data"
    )

    container = Docker.create_container(
        image(rnn);
        attachStdin = true,
        binds = [bind_dataset],
        cmd = runcommand(rnn),
        env = ["LOCAL_USER_ID=$(uid())"],
        kw...
    )

    return container
end
