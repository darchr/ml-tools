
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
@with_kw struct Slim <: AbstractWorkload
    args :: NamedTuple = NamedTuple()
    interactive :: Bool = false
end

image(::Slim) = "darchr/tf-compiled-base"

slim_models(::Type{OnHost}) = joinpath(WORKLOADS, "slim", "src")
slim_models(::Type{OnContainer}) = joinpath("/models", "slim")

startfile(::Slim, ::Type{OnHost}) = joinpath(
    slim_models(OnHost), "train_image_classifier.py"
)

startfile(::Slim, ::Type{OnContainer}) = joinpath(
    slim_models(OnContainer), "train_image_classifier.py"
)

function runcommand(model::Slim) 
    # Extract the arguments from the stuct
    kw = model.args 

    # Check if the "data_dir" arg is present. If not, add it to the default location.
    if !haskey(kw, :dataset_dir) 
        dataset_dir = (dataset_dir = "/imagenet",)
        kw = merge(kw, dataset_dir)
    end

    if !haskey(kw, :dataset_name)
        kw = merge(kw, (dataset_name = "imagenet",))
    end

    if !haskey(kw, :clone_on_cpu)
        kw = merge(kw, (clone_on_cpu = true,))
    end

    # Construct the launch comand
    if model.interactive 
        return `/bin/bash` 
    else
        return `python3 $(startfile(model, OnContainer)) $(makeargs(kw; delim = "="))`
    end
end

function create(model::Slim; kw...)
    # Bind the Imagenet dataset into the top level of the container
    bind_dataset = bind(DATASET_PATHS["imagenet_tf_slim"], "/imagenet")

    # Attach the whole model directory.
    bind_code = bind(slim_models(OnHost), slim_models(OnContainer))

    @show bind_dataset
    @show bind_code

    @show runcommand(model)

    container = Docker.create_container(
        image(model);
        attachStdin = true,
        binds = [bind_dataset, bind_code],
        cmd = runcommand(model),
        env = ["LOCAL_USER_ID=$(uid())"],
        kw...
    )

    return container
end
