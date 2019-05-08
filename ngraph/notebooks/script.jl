#using Pkg; Pkg.activate(".")
using Runner, Zoo, Serialization, nGraph, JuMP

_inception_v4_3027() = Zoo.inception_v4_training(3072)
savefile(::typeof(_inception_v4_3027)) = "inception_v4_3072.jls"

# Resnet
_resnet50_256() = Zoo.resnet_training(Zoo.Resnet50(), 256)
savefile(::typeof(_resnet50_256)) = "resnet50_256.jls"

_resnet200_256() = Zoo.resnet_training(Zoo.Resnet200(), 256)
savefile(::typeof(_resnet200_256)) = "resnet200_256.jls"


#####
##### The function to actually use
#####

f = _resnet200_256
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

# Fractions of the dram limit to use
r = exp10.(range(0, 1; length = nsteps))
r = r .- minimum(r)
fractions = r ./ maximum(r)

simple_iter = simple.(fractions)
synchronous_iter = synchronous.(fractions)

# profiles
style = Runner.OnlyIntermediate()
Runner.compare(f, simple_iter, style; statspath = "serials/simple_" * savefile(f))
Runner.compare(f, synchronous_iter, style; statspath = "serials/synchronous_" * savefile(f))
