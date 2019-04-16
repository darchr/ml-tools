using Runner, Zoo, Serialization, nGraph, JuMP, Plots

Runner.setup_affinities()
Runner.setup_profiling()
Runner.setup_pmem()
Runner.setup_passes()

cache_path = "./timing_cache.jls"

save_cache(cache) = serialize(cache_path, cache)
get_cache() = deserialize(cache_path)

# Get the mnist model and profile the kernel performance
cache = get_cache()
batchsize = 128
fex, args = Zoo.inception_v4_training(batchsize)

# Clear GC to get rid of old function
GC.gc()

data = Runner.profile(fex; cache = cache, saver = save_cache)
save_cache(cache)
serialize("inception_v4_$(batchsize)_training.jls", data)

# Now, we iterate through various model sizes
data = deserialize("inception_v4_$(batchsize)_training.jls")

bounds = Runner.allocation_bounds(data)
nsteps = 15
# Convert dram sizes to MB
sizes = round.(Int, range(bounds.lower_bound, bounds.upper_bound / 2; length = nsteps) ./ 1E6)
special_sizes = [i for i in 100:100:1000]
sizes = sort(vcat(sizes, special_sizes))

sizes_gb = sizes ./ (1E3)

simple_iter = Runner.Simple.(sizes)
function makeplot(model, profile_data, index)
    dram_size = sizes_gb[index]
    title = "VGG 128 - Synchronous. Dram Size: $(dram_size) GB"
    plt = plot(simple_iter[index], profile_data, model, title = title, dpi = 600, size = (1000, 1000))
    png(plt, joinpath(pwd(), "figs", "inception_v4_$(batchsize)_$(dram_size)"))
end

# Save function
function save(rettuple, index) 
    compare_data = (
        sizes_gb = sizes_gb[1:index],
        simple = rettuple,
    )

    serialize("inception_v4_training_$(batchsize)_compare_data.jls", compare_data)
end

fex, compare_data_simple = Runner.compare(simple_iter, fex, args, data; cb = makeplot, save = save)

# No need to do anything with `compare_data_simple` because it will already have been saved.
