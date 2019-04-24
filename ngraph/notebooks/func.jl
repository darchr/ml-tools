function test()
    #nGraph.codegen_debug()
    cache = deserialize("./timing_cache.jls")
    batchsize = 128
    fex, args = Zoo.inception_v4_training(batchsize)
    #fex, args = Zoo.inception_v4_training(batchsize) 
    data = Runner.profile(fex, cache = cache)
    bounds = Runner.allocation_bounds(data)

    x = round(Int, bounds.upper_bound / (1E6 * 10))
    #x = 180000 
    @show x
    S = Runner.Synchronous(x, 29000, 12000)
    #S = Runner.Simple(x) 
    frame = Runner.create_model(S, data)
    optimize!(frame)
    fex, move_nodes_created = Runner.configure!(fex, frame)
    #fex = Runner.configure!(fex, frame) 
    return fex, args, move_nodes_created
end
