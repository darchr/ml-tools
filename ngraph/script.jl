#using Pkg; Pkg.activate(".")
using Runner, Zoo, Serialization, nGraph, JuMP, Plots
#Runner.setup_affinities(omp_num_threads = 23, reserved_cores = 24)
Runner.setup_affinities(omp_num_threads = 24, reserved_cores = 24)
_savedir() = abspath("./serials")

# Resnet
struct Resnet{T}
    batchsize::Int
    zoo::T
end

_sz(::Zoo.Resnet50) = "50"
_sz(::Zoo.Resnet200) = "200"
Runner.name(R::Resnet) = "resnet$(_sz(R.zoo))_batchsize_$(R.batchsize)"
Runner.savedir(R::Resnet) = _savedir()
(R::Resnet)() = Zoo.resnet_training(R.zoo, R.batchsize)

# VGG
struct Vgg{T}
    batchsize::Int
    zoo::T
end
_sz(::Zoo.Vgg19) = "19"
_sz(::Zoo.Vgg416) = "416"
Runner.name(R::Vgg) = "vgg$(_sz(R.zoo))_batchsize_$(R.batchsize)"
Runner.savedir(R::Vgg) = _savedir()
(R::Vgg)() = Zoo.vgg_training(R.zoo, R.batchsize)

# Inception
struct Inception_v4
    batchsize::Int
end
Runner.name(R::Inception_v4) = "inception_v4_batchsize_$(R.batchsize)"
Runner.savedir(R::Inception_v4) = _savedir()
(R::Inception_v4)() = Zoo.inception_v4_training(R.batchsize)

# DenseNet
struct DenseNet
    batchsize::Int
end
Runner.name(R::DenseNet) = "densenet264_batchsize_$(R.batchsize)"
Runner.savedir(R::DenseNet) = _savedir()
(R::DenseNet)() = Zoo.densenet_training(R.batchsize)

# RHN
struct RHN
    num_layers::Int
    depth::Int
    num_steps::Int
    hidden_size::Int
    batch_size::Int
end

Runner.name(R::RHN) = "rhn_$(join(getfield.(Ref(R), fieldnames(RHN)), "_"))"
Runner.savedir(R::RHN) = _savedir()
(R::RHN)() = Zoo.rhn_model_tester(
    num_layers = R.num_layers,
    depth = R.depth,
    num_steps = R.num_steps,
    hidden_size = R.hidden_size,
    batch_size = R.batch_size
)


#####
##### Optimization Generators
#####
struct Static
    limit::Float64
    baseline::Bool
end

Runner.name(::Static) = "static"
function (M::Static)(data)
    bounds = Runner.allocation_bounds(data)
    x = fill(round(Int, bounds.upper_bound * M.limit / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    @show M.baseline
    return Runner.static(x; defrag = !M.baseline)
end

struct Synchronous
    limit::Float64
    baseline::Bool
end

Runner.name(::Synchronous) = "synchronous"
function (M::Synchronous)(data)
    bounds = Runner.allocation_bounds(data)
    x = fill(round(Int, bounds.upper_bound * M.limit / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.synchronous(x, 29000, 12000; defrag = !M.baseline)
end

struct Asynchronous
    limit::Float64
end

Runner.name(::Asynchronous) = "asynchronous"
function (M::Asynchronous)(data)
    bounds = Runner.allocation_bounds(data)
    x = fill(round(Int, bounds.upper_bound * M.limit / 1E6), size(Runner.nodes(data)))
    println("Trying to use $(maximum(x)) MB of memory")
    return Runner.asynchronous(x, 29000, 12000, 2000, 2500; defrag = !M.baseline)
end

#####
##### Test Routine
#####

# Setup functions to Test
fns = (
    #RHN(2, 4, 20, 5000, 512),
    #RHN(2, 4, 10, 10000, 1024),
    #DenseNet(128),
    #Vgg(128, Zoo.Vgg19()),
    #Resnet(128, Zoo.Resnet50()),
    Inception_v4(256),
)

# Setup FUnctions
nsteps = 10

# Fractions of the dram limit to use
r = exp10.(range(0, 1; length = nsteps))
r = r .- minimum(r)
fractions = r ./ maximum(r)

# Reverse so calibration moves from fastest to slowest.
reverse!(fractions)

#####
##### Run Synchronous Tests
#####

# Temporarily get fewer threads
opts = (
    (Static(f, i == 1) for (i, f) in enumerate(fractions)),
    (Synchronous(f, i == 1) for (i, f) in enumerate(fractions)),
)

# Launch the test
fns = (
    #() -> Zoo.inception_v4_training(1024),
    #Vgg(16, Zoo.Vgg19()),
    Inception_v4(1024),
)

Runner.entry(fns, opts, nGraph.Backend("CPU"))

