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
    inference :: Bool = false
    interactive :: Bool = false
end

slim_code(::Type{OnHost}) = joinpath(WORKLOADS, "slim", "src")
slim_code(::Type{OnContainer}) = joinpath("/code", "slim")

slim_models(::Type{OnHost}) = joinpath(WORKLOADS, "slim", "models")
slim_models(::Type{OnContainer}) = joinpath("/models")

startfile(::Slim, ::Type{OnContainer}) = joinpath(
    slim_code(OnContainer), "train_image_classifier.py"
)

inference_file(::Slim, ::Type{OnContainer}) = joinpath(
    slim_code(OnContainer), "eval_image_classifier.py"
)

# Method from: https://github.com/JuliaLang/julia/issues/27574
function dropnames(namedtuple::NamedTuple, names::Tuple{Vararg{Symbol}}) 
   keepnames = Base.diff_names(Base._nt_names(namedtuple), names)
   return NamedTuple{keepnames}(namedtuple)
end

function runcommand(model::Slim) 
    # Extract the arguments from the stuct
    kw = model.args 

    # Check if the "data_dir" arg is present. If not, add it to the default location.
    @default kw dataset_dir "/imagenet"
    @default kw dataset_name "imagenet"
    @default kw clone_on_cpu true

    # Add a label offset so vgg and resnet work correctly automatically
    #
    # The restrictions for VGG and Resnet come from the documentation in 
    # `eval_image_classifier.py`
    if startswith(kw.model_name, "resnet") || startswith(kw.model_name, "vgg") 
        @default kw labels_offset 1
    end

    # Append the "/models/" to the checkpoint_models path
    if !startswith(kw.checkpoint_path, "/models")
        path = kw.checkpoint_path
        kw = dropnames(kw, (:checkpoint_path,))
        @default kw checkpoint_path joinpath("/models", path) 
    end

    # Construct the launch comand
    if model.interactive 
        return `/bin/bash` 
    elseif model.inference
        return `python3 $(inference_file(model, OnContainer)) $(makeargs(kw; delim = "="))`
    else
        return `python3 $(startfile(model, OnContainer)) $(makeargs(kw; delim = "="))`
    end
end

function create(model::Slim; 
        env = [],
        kmp_blocktime = 1, 
        kmp_settings = 1,
        omp_num_threads = 96,
        kw...
    )

    # Bind the Imagenet dataset into the top level of the container
    bind_dataset = bind(DATASET_PATHS["imagenet_tf_slim"], "/imagenet")

    # Attach the whole model directory.
    bind_code = bind(slim_code(OnHost), slim_code(OnContainer))
    bind_models = bind(slim_models(OnHost), slim_models(OnContainer))

    @show bind_dataset
    @show bind_code

    @show runcommand(model)

    # Extend the provided environmental
    localenv = [
        "KMP_BLOCKTIME=$kmp_blocktime",
        "KMP_AFFINITY=granularity=fine,compact,1,0",
        "KMP_SETTINGS=$kmp_settings",
        "OMP_NUM_THREADS=$omp_num_threads",
        "LOCAL_USER_ID=$(uid())",
    ]
    env = vcat(env, localenv)

    container = create_container(
        TensorflowMKL();
        attachStdin = true,
        binds = [bind_dataset, bind_code, bind_models],
        cmd = runcommand(model),
        env = env,
        kw...
    )

    return container
end
