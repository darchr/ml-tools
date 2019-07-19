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

common_functions() = [
    #Inception_v4(1024),
    Resnet200(512),
    #Vgg(2048, Zoo.Vgg19()),
    #DenseNet(512),
]

function go()
    fns = common_functions()
    ratios = common_ratios()

    optimizers = (
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
    pairs = [
        Resnet200(512) => "synchronous",
        Inception_v4(1024) => "synchronous",
    ]

    ratios = common_ratios();

    # Get rid of the all PMEM and all DRAM case
    deleteat!(ratios, findfirst(isequal(0 // 1), ratios)) 

    Runner.pgf_cost(pairs, ratios; cost_ratio = 2.5)
end

