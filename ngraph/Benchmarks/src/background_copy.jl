function make_copy_kernel(
        batchsize,
        conv_config;
        # kwargs for controlling move node generation    
        apply_move = false,
        move_source = Runner.DRAM,
        move_dest = Runner.DRAM,
    )
    nchannels = 128

    # Include the "-" signs to simply add another node between the input and the output,
    # allowing the bias inputs to be profiled by `Runner` instead of just left in DRAM.
    f(w,b) = Chain(
        Conv(-w, -b, relu; pad = 1),
        MaxPool((2,2)),
    )

    # Wrap the convolution insize something that just returns the result of the convolution
    # and just copies `a`.
     
    # Do some operations to `a` so we have control of its source and destination
    g(a, w, b, x) = (a, f(w,b)(x))

    w = rand(Float32, 3, 3, nchannels, nchannels)
    b = rand(Float32, nchannels)
    x = rand(Float32, 112, 112, nchannels, batchsize)
    a = rand(Float32, Int(2E9))

    backend = nGraph.Backend()
    W,B,X = nGraph.Tensor.(Ref(backend), (w,b,x))

    if apply_move && move_source == Runner.PMEM
        A = nGraph.PersistentTensor(backend, a)
    else
        A = nGraph.Tensor(backend, a)
    end

    fex = nGraph.compile(g, A, W, B, X)

    # Step 1: Find the convolution node
    local add_node
    found = false
    for op in fex.ex.ngraph_function
        if nGraph.description(op) == "ConvolutionBias"
            add_node = op
            found = true
            println("Found!")
            break
        end
    end
    @assert found

    # Configure the convolution node
    for (input_config, input) in zip(conv_config.inputs, Runner.inputs(add_node))
        if input_config == Runner.PMEM
            Runner.make_persistent(input)
        end
    end

    for (output_config, output) in zip(conv_config.outputs, Runner.outputs(add_node))
        if output_config == Runner.PMEM
            Runner.make_persistent(output)
        end
    end

    if apply_move
        # Step 2: Find the input parameter - it will be the one whose output is a result
        local target_input
        local target_output
        found = false
        for param in nGraph.get_parameters(fex.ex.ngraph_function)
            println(nGraph.name(param))
            for output_vector in nGraph.get_outputs(param), output in output_vector
                println(nGraph.name(output))
                if Runner.isresult(output)
                    target_input = param
                    target_output = output
                    found = true
                    println("Found!")
                    break
                end
            end
            found && break
        end
        @assert found

        # Just splice a move node for now
        move_node = nGraph.moveasync(target_input, add_node)
        nGraph.splice(
            target_input,  1, 
            target_output, 1, 
            move_node
        )

        # Make the result persistent or not
        if move_dest == Runner.PMEM
            for tensor in Runner.outputs(move_node)
                nGraph.make_persistent(tensor)
            end
        end
    end

    fex = nGraph.recompile(fex)

    return fex
end

function profile_function(fex::nGraph.FluxExecutable)
    # Run the function
    for _ in 1:3
        fex()
    end

    # Get the JSON file and find the convolution node
    json = Runner.read_timing_data(fex.ex.ngraph_function) 

    ind = findfirst(x -> startswith(x["name"], "ConvolutionBias"), json)
    time = json[ind]["dur"]
    return time
end

struct BackgroundCopy end

function benchmark(::Type{BackgroundCopy}; nthreads = 24, batchsize = 128)
    # Reserve 1 thread for movement
    Runner.setup_affinities(omp_num_threads = nthreads-1, reserved_cores = nthreads)

    data = []

    # Setup test iterstors
    tests = [
        (apply_move = true, move_source = Runner.DRAM, move_dest = Runner.PMEM),
        (apply_move = false, move_source = Runner.DRAM, move_dest = Runner.DRAM),
        (apply_move = true, move_source = Runner.DRAM, move_dest = Runner.DRAM),
        (apply_move = true, move_source = Runner.PMEM, move_dest = Runner.DRAM),
    ]

    _dp = (Runner.DRAM, Runner.PMEM)
    configs = 
        [Runner.IOConfig((a,Runner.DRAM,Runner.DRAM), (d,)) for (a,d) in Iterators.product(_dp, _dp)] |>
        x -> reshape(x, :)

    for (config, test) in Iterators.product(configs, tests)
        fex = make_copy_kernel(batchsize, config;
            apply_move = test.apply_move,
            move_source = test.move_source,
            move_dest = test.move_dest,
        )

        time = profile_function(fex)

        this_data = (
            nthreads = nthreads,
            time = time,
            apply_move = test.apply_move,
            move_source = test.move_source,
            move_dest = test.move_dest,
            config = config,
        )

        push!(data, this_data)
    end

    return data
end

function gen_plot(::Type{Kernel}, data; 
        file = "plot.tex", 
        preamble = true,
        config_mask = AlwaysTrue(),
    )
    # Sort by number of threads.
    sort!(data; by = x -> x.nthreads)

    # Collect and sort all of the IO configurations for this kernel
    configs = first(data).timings |> keys |> collect |> sort 

    # Filter out configs specified by the config mask
    configs = unique(x -> [x[i] for i in 1:length(x) if config_mask[i]], configs)
    @show configs

    # Normalize to the fastest kernel
    normalization = minimum(getproperty.(data, :time))
    plots = [Plot(Coordinates(_coordinates(d.timings, configs, normalization))) for d in data]
    #legend = ["$(d.nthreads) Threads" for d in data]

    plt = @pgf Axis(
        {
            ybar,
            enlarge_x_limits=0.20,
            legend_style =
            {
                 at = Coordinate(0.5, 1.15),
                 anchor = "south east",
                 legend_columns = -1
            },
            symbolic_x_coords=stringify.(configs),
            nodes_near_coords_align={vertical},
            ylabel="Performance relative to\\\\24 threadswith all IO in DRAM",
            ymajorgrids,
            ymin=0,
            ylabel_style={
                align = "center",
            },
            xlabel="IO Configuration",
            xtick="data",
            xticklabel_style={
                rotate = 75,
                #"/pgf/number format/1000 sep=",
            },
            yticklabel_style={
                "/pgf/number format/fixed",
                "/pgf/number format/precision=5",
            },
            bar_width="20pt",
            width = "15cm",
            height = "5cm",
        },
        plots...,
        #Legend(legend),
    )

    pgfsave(file, plt; include_preamble = preamble)
    return nothing
end
