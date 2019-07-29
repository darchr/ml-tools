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

function convergence_test()
    inner_iterations = 1000
    outer_iterations = 5
    f = Resnet50(32)

    backend = nGraph.Backend("GPU")
    env = ("NGRAPH_GPU_CUDA_MALLOC_MANAGED" => true,)

    opts = (
        Runner.Synchronous(GPU_ADJUSTED_MEMORY),
        Runner.Asynchronous(GPU_ADJUSTED_MEMORY),
    )

    # Get the results
    results = Runner.track(backend, f, opts; 
        env = env, 
        inner_iterations = inner_iterations, 
        outer_iterations = outer_iterations
    )

    serialize(joinpath(@__DIR__, "..", Runner.name(f) * "_results.jls"), results)
    return nothing
end

_mkname(s::String) = s
_mkname(s::Runner.AbstractOptimizer) = Runner.name(s)

function plot_convergence(path; file = "plot.tex")
    results = deserialize(path)::Dict
    # opt - The type of optimizer. WIll be a `String` for the baseline, otherwise will be
    #     some kind of AbstractOptimizer
    #
    # data - `Vector{Vector{<:Number}}`. Each inner vector corresponds to a single trial
    #     for the optimizer. The outer vectors correspond to multiple trials.
    plots = []
    colors = ("blue", "red", "black")
    for (i, (opt, data)) in enumerate(results)
        for run in data
            append!(plots, [
                @pgf(PlotInc(
                    {
                        solid,
                        color = colors[i],
                        no_markers,
                    },
                    Coordinates(1:length(run), run)
                )),
                @pgf(LegendEntry(_mkname(opt))),
            ])
        end
    end

    plt = @pgf Axis(
        {
            legend_style = {
                at = Coordinate(1.0, 1.0),
                anchor = "north west",
            },
        },
        plots...
    )

    pgfsave(file, plt)
end
