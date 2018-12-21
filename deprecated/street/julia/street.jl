@with_kw struct Street <: AbstractWorkload
    args :: NamedTuple = NamedTuple()
    interactive::Bool = false
end

image(::Street) = "darchr/tf-compiled-base"

_street(::Type{OnHost}) = joinpath(WORKLOADS, "tensorflow", "street")
_street(::Type{OnContainer}) = joinpath("/street")

entryfile(::Street, ::Type{OnContainer}) = joinpath(
    _street(OnContainer), "runscript.sh"
)

startfile(::Street, ::Type{OnContainer})  = joinpath(
    _street(OnContainer), "python", "vgsl_train.py",
)

# We need to compile the LSTM operation before running the model. Since we don't know
# what kind of computer we will be running on, this is the first action done inside the
# container.
#
# To that end, the actual entry point is a script that compiled the operation and then
# forwards the rest of the arguments - effectively calling the python script.
function runcommand(street::Street)
    kw = street.args

    if !haskey(kw, :train_data)
        kw = merge(kw, (train_data = "/fsns/train/train*",))
    end

    if !haskey(kw, :train_dir)
        kw = merge(kw, (train_dir = "/tmp/fsns",))
    end

    args = makeargs(kw, "=")
    entry = entryfile(street, OnContainer)
    start = startfile(street, OnContainer)

    if street.interactive
        return `bin/bash $entry`
    else
        return `bin/bash $entry $start $args`
    end
end

function create(street::Street; kw...)
    datasetpath = DATASET_PATHS["fsns"]
    bind_dataset = bind(datasetpath, "/fsns")

    # Attach the code directory
    bind_code = bind(_street(OnHost), _street(OnContainer))

    container = DockerX.create_container(
        image(street);
        attachStdin = true,
        binds = [bind_dataset, bind_code],
        cmd = runcommand(street),
        env = ["LOCAL_USER_ID=$(uid())"],
        kw...
    )
end
