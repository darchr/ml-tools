# Produce results for benchmarking a kernel under different IO conditions
# We choose a relatively common Convolution kernel.
function make_kernel(backend, batchsize = 128)
    nchannels = 128

    # Include the "-" signs to simply add another node between the input and the output,
    # allowing the bias inputs to be profiled by `Runner` instead of just left in DRAM.
    f(w,b) = Chain(
        Conv(-w, -b, relu; pad = 1),
        MaxPool((2,2)),
    )

    w = rand(Float32, 3, 3, nchannels, nchannels)
    b = rand(Float32, nchannels)
    x = rand(Float32, 112, 112, nchannels, batchsize)

    W,B,X = nGraph.Tensor.(Ref(backend), (w,b,x))

    F = nGraph.compile(backend, (w,b,x) -> f(w,b)(x), W,B,X)
    return F
end

const TEMP_CACHE = joinpath(@__DIR__, "temp_cache.jls")

function profile_kernel(backend, fex::nGraph.FluxExecutable)
    # Create a local cache for the profiler
    cache = Runner.CPUKernelCache(TEMP_CACHE; force_new = true)
    data = Runner.profile(fex.ex.ngraph_function, backend; cache = cache)

    # Find the "ConvolutionBias" kernel
    kernel = findfirst(x -> nGraph.description(x) == "ConvolutionBias", Runner.nodes(data))
    return data.timings[Runner.nodes(data, kernel)]
end

struct Kernel end

# For whatever reason, ngraph is refusing to change the number of threads being used here.
#
# On the TODO list is to figure out why and fix it so we can collect data for multiple
# numbers of threads
function benchmark(::Type{Kernel};
        threads = (24,),
        batchsize = 128,
    )

    backend = nGraph.Backend("CPU")
    data = []
    for nthreads in threads
        # Set the environment variables correctly
        Runner.setup_affinities(; omp_num_threads = nthreads)

        # Profile kernel
        timings = profile_kernel(backend, make_kernel(backend, batchsize))
        this_data = (
            nthreads = nthreads,
            timings = timings
        )
        push!(data, this_data)
    end
    return data
end

function stringify(c::Runner.IOConfig)
    f = x -> x == Runner.PMEM ? "P" : "D"

    ins = "$(join(f.(c.inputs)))"
    outs = "$(join(f.(c.outputs)))"
    return "$ins $outs"
end

function make_plot(::Type{Kernel})
    data = first.(deserialize("kernel_data.jls"))

    xticks = [
        "DRAM\\\\DRAM",
        "DRAM\\\\PMM",
        "PMM\\\\DRAM",
        "PMM\\\\PMM",
    ]

    gen_plot(Kernel, data;
        config_mask = (true, false, false, true),
        xticks = xticks,
        width = "8cm",
        height = "5cm",
    )
end

struct AlwaysTrue end
Base.getindex(::AlwaysTrue, args...) = true

_coordinates(d::Dict, configs::Vector{Runner.IOConfig}, normalization) = 
    [(i, d[c] / normalization) for (i, c) in enumerate(configs)]


function gen_plot(::Type{Kernel}, data; 
        file = "plot.tex", 
        preamble = true,
        # Take configs for the first input and first (and only) output by default
        config_mask = (true, false, false, true),
        xticks = nothing,
        width = "5cm",
        height = "2cm",
    )
    # Sort by number of threads.
    sort!(data; by = x -> x.nthreads)

    # Collect and sort all of the IO configurations for this kernel
    configs = first(data).timings |> keys |> collect |> sort 

    # Filter out configs specified by the config mask
    configs = unique(x -> [x[i] for i in 1:length(x) if config_mask[i]], configs)
    display(configs)

    # Normalize to the fastest kernel
    normalization = minimum(minimum.(values.(getproperty.(data, :timings))))

    plots = [
        Plot(Coordinates(_coordinates(d.timings, configs, normalization))) for d in data
    ]

    legend = ["$(d.nthreads) Threads" for d in data]

    plt = TikzDocument()
    push!(plt, """
    \\pgfplotsset{
        width=$width,
        height=$height
    }
    """)

    tikz = TikzPicture()
    axs = @pgf Axis(
        {
            ybar,
            enlarge_x_limits=0.20,
            legend_style =
            {
                 at = Coordinate(0.5, 1.15),
                 anchor = "south east",
                 legend_columns = -1
            },
            #symbolic_x_coords = xticks,
            nodes_near_coords_align={vertical},
            ylabel="Performance relative\\\\to all IO in DRAM",
            ymajorgrids,
            ymin=0,
            ylabel_style={
                align = "center",
            },
            #xlabel="IO Configuration",
            xtick="data",
            xticklabels = xticks,
            xticklabel_style={
                align = "center",
                #rotate = 75,
                #"/pgf/number format/1000 sep=",
            },
            yticklabel_style={
                "/pgf/number format/fixed",
                "/pgf/number format/precision=5",
            },
            bar_width="20pt",
            #width = "15cm",
            #height = "5cm",
        },
        plots...,
        #Legend(legend),
    )

    push!(tikz, axs)
    push!(plt, tikz)

    pgfsave(file, plt; include_preamble = preamble)
    return nothing
end
