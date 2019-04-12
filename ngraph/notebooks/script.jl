using Pkg; Pkg.activate()
using Runner, Zoo, Serialization, nGraph, JuMP, Plots

Runner.setup_affinities()
Runner.setup_profiling()
Runner.setup_pmem()

cache_path = "./timing_cache.jls"

save_cache(cache) = serialize(cache_path, cache)
get_cache() = deserialize(cache_path)

# Get the mnist model and profile the kernel performance
cache = get_cache()
fex, args = Zoo.inception_v4_training(128)

data = Runner.profile(fex; cache = cache, saver = save_cache)
save_cache(cache)
bounds = Runner.allocation_bounds(data)
