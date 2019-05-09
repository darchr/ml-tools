#using Pkg; Pkg.activate(".")
using Runner, Zoo, Serialization, nGraph, JuMP

# Inception
_inception_v4_3072() = Zoo.inception_v4_training(3072)
savefile(::typeof(_inception_v4_3072)) = "inception_v4_3072.jls"

# Resnet
_resnet50_256() = Zoo.resnet_training(Zoo.Resnet50(), 256)
savefile(::typeof(_resnet50_256)) = "resnet50_256.jls"

_resnet200_256() = Zoo.resnet_training(Zoo.Resnet200(), 256)
savefile(::typeof(_resnet200_256)) = "resnet200_256.jls"

# Vgg
_vgg416_128() = Zoo.vgg_training(Zoo.Vgg416(), 128)
savefile(::typeof(_vgg416_128)) = "vgg416_128.jls"

_vgg19_128() = Zoo.vgg_training(Zoo.Vgg19(), 128)
savefile(::typeof(_vgg19_128)) = "vgg19_128.jls"


#####
##### The function to actually use
#####

f = _vgg416_128
skip_run = true
nsteps = 20

# Generator functions for the various optimization methods
simple(n) = function(data)
    bounds = Runner.allocation_bounds(data)
    x = round(Int, bounds.upper_bound * n / 1E6)
    return Runner.Simple(x)
end

synchronous(n) = function(data)
    bounds = Runner.allocation_bounds(data)
    x = round(Int, bounds.upper_bound * n / 1E6)
    println("Trying to use $x MB of memory")
    return Runner.Synchronous(x, 29000, 12000)
end

# # Fractions of the dram limit to use
# r = exp10.(range(0, 1; length = nsteps))
# r = r .- minimum(r)
# fractions = r ./ maximum(r)
# 
# simple_iter = simple.(fractions)
# synchronous_iter = synchronous.(fractions)
# 
# # Liveness Analysis
# style = Runner.OnlyIntermediate()
# prefix = skip_run ? "skipped" : ""
# 
# # Simple formulation
# file = "serials/" * prefix * "simple_" * savefile(f)
# Runner.compare(f, simple_iter, style; statspath = file, skip_run = skip_run)
# 
# # Synchronous Formulation
# file = "serials/" * prefix * "synchronous_" * savefile(f)
# Runner.compare(f, synchronous_iter, style; statspath = file, skip_run = skip_run)
