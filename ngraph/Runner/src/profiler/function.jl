# Timing methods for the whole function

function gettime(fex::nGraph.FluxExecutable, args; timeout = Second(10), min_calls = 3)
    start = now()
    mintime = typemax(Float64)
    times = 1
    while (now() < start + timeout) || (times <= min_calls)
        runtime = @elapsed(fex(args...))
        mintime = min(mintime, runtime)
        times += 1
    end
    return mintime
end

function all_dram_time(fex, args)
    # Get timing for All DRAM
    backend = fex.ex.backend
    Runner._cleanup!(fex.ex.ngraph_function)
    fex = nGraph.recompile(fex)
    return fex, gettime(fex, args)
end

function all_pmem_time(fex, args, profile_data)
    backend = fex.ex.backend

    # Get timing for All PMEM
    for fn_node in fex.ex.ngraph_function
        Runner.keep(fn_node) || continue

        # Check the output tensors of this node can live in PMEM. If so, assign them there
        for tensor in nGraph.output_descriptors(fn_node)
            tensor_name = nGraph.get_name(tensor)
            if in(Runner.PMEM, profile_data.tensors[tensor_name].locations)
                nGraph.make_persistent(tensor)
            end
        end
    end
    fex = nGraph.recompile(fex)
    pmem_time = gettime(fex, args)

    return fex, pmem_time
end

#function compare(iter, fex::nGraph.FluxExecutable, args, profile_data;
function compare(f, opt_iter;
        cb = (x...) -> nothing,
        save = (x...) -> nothing,
        cache = CPUKernelCache(),
    )

    # Run each of the test functions
    predicted_runtimes = Float64[]
    actual_runtimes = Float64[]
    dram_limits = Int64[] 

    # Keep the parsed JSON of kernel timings for comparison with the predicted value
    kernel_times = Vector{Any}[]
    local rettuple

    for (index, opt) in enumerate(opt_iter)
        println("Processing $index of $(length(opt_iter))")
        fex, args, frame, _metadata = factory(f, opt; cache = cache, save = save)

        # Get the predicted run time and then the actual run time
        push!(predicted_runtimes, Runner.predict(frame))
        push!(actual_runtimes, gettime(fex, args))
        push!(dram_limits, limit(frame.modeltype))
        push!(kernel_times, read_timing_data(fex.ex.ngraph_function))

        @info """
        Predicted Run Time: $(last(predicted_runtimes))
        Actual Run Time: $(last(actual_runtimes))
        """

        # Prepare the return values
        rettuple = (
            predicted_runtimes = predicted_runtimes,
            actual_runtimes = actual_runtimes,
            dram_limits = dram_limits,
            kernel_times = kernel_times,
        )

        # Do this for GC purposes
        #
        # Sometimes the nGraph executable can be very large. Call the GC here to clean it
        # up before the next round.
        nGraph._cleanup(fex.ex)
    end

    return rettuple
end

#####
##### Intraction methods with the `rettuple` from `compare`
#####

dc(x) = all(isequal(Runner.DRAM), x)
pmem_count(x) = count(isequal(Runner.PMEM), x)

function gettimings(data)
    timings = NamedTuple[]

    for node in data.nodes
        Runner.keep(node) || continue
        configs = collect(keys(node.timings))

        dram_config = configs[findfirst(x -> dc(x.inputs) && dc(x.outputs), configs)]
        input_dram = filter(x -> dc(x.inputs), configs) |> collect
        output_dram = filter(x -> dc(x.outputs), configs) |> collect

        # Find the configs with the most inputs in PMEM with all outputs in DRAM
        # and find the config with the most outputs in PMEM with all inputs in DRAM
        _, i = findmax(map(x -> pmem_count(x.inputs), output_dram))
        max_input_pmem_config = output_dram[i]

        _, i = findmax(map(x -> pmem_count(x.outputs), input_dram))
        max_output_pmem_config = input_dram[i]

        # Find the comfig with the most number of PMEM io
        _, i = findmax(map(x -> pmem_count(x.inputs) + pmem_count(x.outputs), configs))
        max_pmem_config = configs[i]

        nt = (
            description = node.description,
            dram = minimum(node.timings[dram_config]),
            pmem = minimum(node.timings[max_pmem_config]),
            input_pmem = minimum(node.timings[max_input_pmem_config]),
            output_pmem = minimum(node.timings[max_output_pmem_config]),
        )
        push!(timings, nt)
    end
    return timings
end

#####
##### Plotting
#####

struct PlotDispatch end

@recipe function f(::PlotDispatch, timings, key; legend = nothing)
    # Sort by key ratio over DRAM
    sort!(timings; by = x -> getproperty(x, key) / x.dram)

    # Get all the unique descriptions
    descriptions = unique(map(x -> x.description, timings))

    seriestype := :scatter
    legend := legend
    #yaxis := :log10

    xlabel := "Kernel Number"
    ylabel := "Execution time with respect to all DRAM"

    for d in descriptions
        x = Int[]
        y = Float64[]
        for (i, timing) in enumerate(timings)
            timing.description == d || continue

            push!(x, i)
            push!(y, getproperty(timing, key) ./ timing.dram)
        end
        @series begin
            lab := d
            x,y
        end
    end
end
