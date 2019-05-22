#using Pkg; Pkg.activate(".")
using Runner, Zoo, Serialization, nGraph, JuMP

# # Inception
# _inception_v4_3072() = Zoo.inception_v4_training(3072)
# savefile(::typeof(_inception_v4_3072)) = "inception_v4_3072.jls"
# 
# _inception_v4_3200() = Zoo.inception_v4_training(3200)
# savefile(::typeof(_inception_v4_3200)) = "inception_v4_3200.jls"
# 
# _inception_v4_256() = Zoo.inception_v4_training(256)
# savefile(::typeof(_inception_v4_256)) = "inception_v4_256.jls"
# 
# _inception_v4_128() = Zoo.inception_v4_training(128)
# savefile(::typeof(_inception_v4_128)) = "inception_v4_128.jls"

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

# 
# _resnet50_256() = Zoo.resnet_training(Zoo.Resnet50(), 256)
# savefile(::typeof(_resnet50_256)) = "resnet50_256.jls"
# 
# _resnet200_256() = Zoo.resnet_training(Zoo.Resnet200(), 256)
# savefile(::typeof(_resnet200_256)) = "resnet200_256.jls"
# 
# _resnet200_128() = Zoo.resnet_training(Zoo.Resnet200(), 128)
# savefile(::typeof(_resnet200_128)) = "resnet200_128.jls"
# 
# # Vgg
# _vgg416_128() = Zoo.vgg_training(Zoo.Vgg416(), 128)
# savefile(::typeof(_vgg416_128)) = "vgg416_128.jls"
# 
# _vgg416_160() = Zoo.vgg_training(Zoo.Vgg416(), 160)
# savefile(::typeof(_vgg416_160)) = "vgg416_160.jls"
# 
# _vgg19_128() = Zoo.vgg_training(Zoo.Vgg19(), 128)
# savefile(::typeof(_vgg19_128)) = "vgg19_128.jls"
# 
# # DenseNet
# _densenet264_128() = Zoo.densenet_training(128)
# savefile(::typeof(_densenet264_128)) = "densenet264_128"

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
    Resnet(128, Zoo.Resnet50()),
    Vgg(256, Zoo.Vgg19()),
    Inception_v4(256),
)

# Setup FUnctions
nsteps = 20

# Fractions of the dram limit to use
r = exp10.(range(0, 1; length = nsteps))
r = r .- minimum(r)
fractions = r ./ maximum(r)

opts = Iterators.flatten((
    (MyStatic(f) for f in fractions),
    (MySynchronous(f) for f in fractions),
))

# Launch the test
Runner.entry(fns, opts)

