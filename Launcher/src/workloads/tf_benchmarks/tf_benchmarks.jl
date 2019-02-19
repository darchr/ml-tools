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
@with_kw struct TFBenchmark <: AbstractWorkload
    args :: NamedTuple = NamedTuple()
    interactive :: Bool = false
end

_srcdir(::TFBenchmark, ::Type{OnHost}) = joinpath(WORKLOADS, "tf_cnn_benchmarks", "src")
_srcdir(::TFBenchmark, ::Type{OnContainer}) = joinpath("/tf_cnn_benchmarks")

startfile(T::TFBenchmark, ::Type{OnContainer}) = joinpath(
    _srcdir(T, OnContainer), "tf_cnn_benchmarks.py"
)

function runcommand(model::TFBenchmark) 
    # Extract the arguments from the stuct
    kw = model.args 

    # Check if the "data_dir" arg is present. If not, add it to the default location.
    @default kw data_dir "/imagenet"
    @default kw data_name "imagenet"
    @default kw device "cpu"
    @default kw data_format "NCHW"
    @default kw mkl true

    # Construct the launch comand
    if model.interactive 
        return `/bin/bash` 
    else
        return `python3 $(startfile(model, OnContainer)) $(makeargs(kw; delim = "="))`
    end
end

function create(model::TFBenchmark; kw...)
    # Bind the Imagenet dataset into the top level of the container
    bind_dataset = bind(DATASET_PATHS["imagenet_tf_slim"], "/imagenet")

    # Attach the whole model directory.
    bind_code = bind(_srcdir(model, OnHost), _srcdir(model, OnContainer))

    @show runcommand(model)

    container = create_container(
        TensorflowMKL();
        binds = [bind_dataset, bind_code],
        cmd = runcommand(model),
        env = [
            "LOCAL_USER_ID=$(uid())",
            "KMP_BLOCKTIME=0",
            "OMP_NUM_THREADS=24",
            "KMP_AFFINITY=quiet,granularity=fine,compact,1,0",
        ],
        kw...
    )

    return container
end



function benchmark_timeparser(io::IO)
    # Outputs look like this:
    # 1	    images/sec: 38.0 +/- 0.0 (jitter = 0.0)	7.419
    # 10	images/sec: 22.6 +/- 2.5 (jitter = 1.3)	7.593
    # 20	images/sec: 21.1 +/- 1.6 (jitter = 2.7)	7.597
    # 30	images/sec: 22.4 +/- 1.5 (jitter = 4.5)	7.683
    # 40	images/sec: 22.7 +/- 1.3 (jitter = 4.3)	7.576
    # 50	images/sec: 22.8 +/- 1.2 (jitter = 3.9)	7.442
    #
    # Doing a brute-force parsing is pretty straightforward
    seekstart(io) 

    images_per_second = Float64[]
    for ln in eachline(io)
        if occursin("images/sec:", ln) 
            split_str = split(ln)
            push!(images_per_second, parse(Float64, split_str[3]))
        end
    end
    return mean(images_per_second)
end

"""
    Launcher.benchmark_timeparser(file::String) -> Float64

Return the average number of images processed per second by the [`TFBenchmark`] workload.
Applicable when the output is of the form below:

```    
OMP: Info #250: KMP_AFFINITY: pid 1 tid 8618 thread 189 bound to OS proc set 93
OMP: Info #250: KMP_AFFINITY: pid 1 tid 8619 thread 190 bound to OS proc set 94
OMP: Info #250: KMP_AFFINITY: pid 1 tid 8620 thread 191 bound to OS proc set 95
OMP: Info #250: KMP_AFFINITY: pid 1 tid 8621 thread 192 bound to OS proc set 0
Done warm up
Step	Img/sec	total_loss
1	images/sec: 38.0 +/- 0.0 (jitter = 0.0)	7.419
10	images/sec: 22.6 +/- 2.5 (jitter = 1.3)	7.593
20	images/sec: 21.1 +/- 1.6 (jitter = 2.7)	7.597
30	images/sec: 22.4 +/- 1.5 (jitter = 4.5)	7.683
40	images/sec: 22.7 +/- 1.3 (jitter = 4.3)	7.576
50	images/sec: 22.8 +/- 1.2 (jitter = 3.9)	7.442
```
"""
benchmark_timeparser(path::String) = open(benchmark_timeparser, path)
