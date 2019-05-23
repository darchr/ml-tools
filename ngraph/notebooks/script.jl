#using Pkg; Pkg.activate(".")
using Runner, Zoo, Serialization, nGraph, JuMP

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

#####
##### Optimization Generators
#####
struct MyStatic
    limit::Float64
end

Runner.name(::MyStatic) = "static"
function (M::MyStatic)(data)
    bounds = Runner.allocation_bounds(data)
    x = round(Int, bounds.upper_bound * M.limit / 1E6)
    println("Trying to use $x MB of memory")
    return Runner.Static(x)
end

struct MySynchronous
    limit::Float64
end

Runner.name(::MySynchronous) = "synchronous"
function (M::MySynchronous)(data)
    bounds = Runner.allocation_bounds(data)
    x = round(Int, bounds.upper_bound * M.limit / 1E6)
    println("Trying to use $x MB of memory")
    return Runner.Synchronous(x, 29000, 12000)
end

#####
##### Test Routine
#####

# Setup functions to Test
fns = (
    Vgg(128, Zoo.Vgg19()),
    Resnet(128, Zoo.Resnet50()),
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

opts = Iterators.flatten((
    (MySynchronous(f) for f in fractions),
    (MyStatic(f) for f in fractions),
))

# Launch the test
Runner.entry(fns, opts)

