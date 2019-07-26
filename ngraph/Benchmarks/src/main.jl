# Main benchmrarks for the paper thing

#####
##### Convenience Wrappers for models
#####
_savedir() = abspath("./serials")

# Resnet
struct Resnet{T}
    batchsize::Int
    zoo::T
end
Resnet50(batchsize) = Resnet(batchsize, Zoo.Resnet50())
Resnet200(batchsize) = Resnet(batchsize, Zoo.Resnet200())

_sz(::Zoo.Resnet50) = "50"
_sz(::Zoo.Resnet200) = "200"
Runner.name(R::Resnet) = "resnet$(_sz(R.zoo))_batchsize_$(R.batchsize)"
Runner.titlename(R::Resnet) = "Resnet$(_sz(R.zoo))"

Runner.savedir(R::Resnet) = _savedir()
(R::Resnet)() = Zoo.resnet_training(R.zoo, R.batchsize)

# VGG
struct Vgg{T}
    batchsize::Int
    zoo::T
end
Vgg19(batchsize) = Vgg(batchsize, Zoo.Vgg19())
Vgg416(batchsize) = Vgg(batchsize, Zoo.Vgg416())

_sz(::Zoo.Vgg19) = "19"
_sz(::Zoo.Vgg416) = "416"
Runner.name(R::Vgg) = "vgg$(_sz(R.zoo))_batchsize_$(R.batchsize)"
Runner.titlename(R::Vgg) = "Vgg$(_sz(R.zoo))"

Runner.savedir(R::Vgg) = _savedir()
(R::Vgg)() = Zoo.vgg_training(R.zoo, R.batchsize)

# Inception
struct Inception_v4
    batchsize::Int
end
Runner.name(R::Inception_v4) = "inception_v4_batchsize_$(R.batchsize)"
Runner.titlename(::Inception_v4) = "Inception v4"

Runner.savedir(R::Inception_v4) = _savedir()
(R::Inception_v4)() = Zoo.inception_v4_training(R.batchsize)

# DenseNet
struct DenseNet
    batchsize::Int
end
Runner.name(R::DenseNet) = "densenet264_batchsize_$(R.batchsize)"
Runner.savedir(R::DenseNet) = _savedir()
(R::DenseNet)() = Zoo.densenet_training(R.batchsize)

#####
##### Helpers for benchmark routines
#####

conventional_inception() = Inception_v4(1024)
conventional_resnet() = Resnet200(512)
conventional_vgg() = Vgg19(2048)
conventional_densenet() = DenseNet(512)

common_ratios() = [
    1 // 0,
    8 // 1,
    4 // 1,
    2 // 1,
    1 // 1,
    1 // 2,
    1 // 4,
    0 // 1,
]

conventional_functions() = [
    conventional_inception(),
    conventional_resnet(),
    conventional_vgg(),
    conventional_densenet(),
]

function go()
    fns = (
        conventional_resnet(),
        #conventional_vgg(),
        conventional_inception(),
        conventional_densenet(),
    )

    ratios = common_ratios()

    optimizers = (
        [Runner.Static(r) for r in ratios],
        [Runner.Synchronous(r) for r in ratios],
        #[Runner.Asynchronous(r) for r in ratios],
        [Runner.Numa(r) for r in ratios],
    )

    Runner.entry(fns, optimizers, nGraph.Backend("CPU"))
end

#####
##### Functions for generating plots
#####

function plot_speedup(model)
    ratios = common_ratios();

    # Get rid of the all PMEM and all DRAM case
    deleteat!(ratios, findfirst(isequal(0 // 1), ratios))
    deleteat!(ratios, findfirst(isequal(1 // 0), ratios))

    Runner.pgf_speedup(
        model,
        ratios;
        formulations = ("numa", "static", "synchronous")
    )
end

function plot_costs()
    pairs = [conventional_resnet() => "synchronous",
             conventional_inception() => "synchronous",
             conventional_vgg() => "synchronous",
            ]

    ratios = common_ratios();

    # Get rid of the all PMEM and all DRAM case
    deleteat!
    (ratios, findfirst(isequal(0 // 1), ratios))

    Runner.pgf_cost(pairs, ratios; cost_ratio = 2.5)
end

#####
##### Geneation of specific figures
#####

# Speedup Plots
inception_speedup() = plot_speedup(conventional_inception())
vgg_speedup() = plot_speedup(conventional_vgg())
resnet_speedup() = plot_speedup(conventional_resnet())

# In depth analysis
function inception_analysis_plots()
    f = conventional_inception()

    # Performance line graph
    Runner.pgf_plot_performance(f; file = "inception_perf.tex")

    # Input/output tensor graph
    Runner.pgf_io_plot(f;
                       file = "inception_io.tex",
                       formulations = ("static", "synchronous")
                      )

    # Movement statistics
    Runner.pgf_stats_plot(conventional_inception();
                          file = "inception_movement.tex",
                          formulation = "synchronous"
                         )

end

#####
##### GPU Benchmarks
#####

const GPU_MAX_MEMORY = 11_000_000_000

# Got this number from looking at nvidia-smi after all the GPU initialization code
# in ngraph runs.
#
# Probably worth double-checking
const GPU_MEMORY_OVERHEAD = 561_000_000
const GPU_ADJUSTED_MEMORY = GPU_MAX_MEMORY - GPU_MEMORY_OVERHEAD

# For the GPU, we have a hard limit of 11 GB,
gpu_fns() = (
    Inception_v4(64),
    Inception_v4(128),
    Inception_v4(256),
    Resnet200(32),
    Resnet200(64),
    Resnet200(128),
    DenseNet(32),
    DenseNet(64),
    DenseNet(128),
)

function gpu_go()
    fns = Iterators.flatten((
        gpu_fns(),
    ))

    limit = GPU_ADJUSTED_MEMORY

    # Wrap in a wierd double tuple thing to trick the flattening logic into doing the
    # right thing.
    optimizers = ((
        Runner.Synchronous(limit),
        Runner.Asynchronous(limit),
    ),)

    Runner.entry(fns, optimizers, nGraph.Backend("GPU"))
end

function plot_gpu_performance()
    fns = Iterators.flatten((
        gpu_fns(),
    ))

    Runner.pgf_gpu_performance_plot(fns)
end
