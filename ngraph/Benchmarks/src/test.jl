function cpu_test()
    iterations = 10
    fns = (
        Resnet50(64),
    )

    ratios = [
        1 // 0,
        2 // 1,
        1 // 1,
    ]

    optimizers = (
        [Runner.Static(r) for r in ratios],
        [Runner.Synchronous(r) for r in ratios],
    )

    backend = nGraph.Backend("CPU")

    results = []
    for f in fns
        for opt in Iterators.flatten(optimizers)
            passed = Runner.verify(
                backend,
                f,
                opt;
                iterations = iterations,
            )
            push!(results, (f, opt, passed))
        end
    end
    return results
end

function gpu_test()
    # Number of test iterations
    iterations = 10

    fns = (
        #Vgg19(128),
        Resnet50(128),
        #Inception_v4(128),
    )

    limit = GPU_ADJUSTED_MEMORY
    optimizers = (
        Runner.Synchronous(limit),
        #Runner.Asynchronous(limit),
    )

    backend = nGraph.Backend("GPU")

    results = []
    for f in fns
        for opt in optimizers
            passed = Runner.verify(
                backend,
                f,
                opt;
                env = ("NGRAPH_GPU_CUDA_MALLOC_MANAGED" => true,),
                iterations = iterations,
            )
            push!(results, (f, opt, passed))
        end
    end
    return results
end
