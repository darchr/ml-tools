using Pkg; Pkg.activate(".")
using Runner, Zoo, Serialization, nGraph, JuMP

#f = () -> Zoo.inception_v4_training(3072)
f = () -> Zoo.resnet_training(50, 256)
#f = () -> Zoo.vgg19_training(128)
nsteps = 6

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
fractions = fractions[2:end]

simple_iter = simple.(fractions)
synchronous_iter = synchronous.(fractions)

# profiles
#simple_data = Runner.compare(f, simple_iter; statspath = "serials/inception_v4_3072_simple.jls")
#synchronous_data = Runner.compare(f, synchronous_iter; statspath = "serials/inception_v4_3072_synchronous.jls")
#simple_data = Runner.compare(f, simple_iter; statspath = "serials/resnet200_256_simple.jls")
#synchronous_data = Runner.compare(f, synchronous_iter; statspath = "serials/resnet200_256_synchronous.jls")
#simple_data = Runner.compare(f, simple_iter; statspath = "serials/vgg416_128_simple.jls")
#synchronous_data = Runner.compare(f, synchronous_iter; statspath = "serials/vgg416_128_synchronous.jls")
synchronous_data = Runner.compare(f, synchronous_iter; statspath = "serials/test.jls")
