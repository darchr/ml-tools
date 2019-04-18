function test()
    cache = deserialize("./timing_cache.jls")
    batchsize = 128
    fex, args = Zoo.vgg19_training(batchsize)
    data = Runner.profile(fex, cache = cache)
    bounds = Runner.allocation_bounds(data)

    x = round(Int, bounds.upper_bound / (1E6 * 10))
    S = Runner.Synchronous(x, 100000, 100000)
    frame = Runner.create_model(S, data)
    optimize!(frame)
    config = Runner.configure!(fex, frame)
    return config
end
