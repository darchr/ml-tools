# Timing methods for the whole function

function gettime(fex::nGraph.FluxExecutable; timeout = Second(10), min_calls = 2)
    start = now()
    mintime = typemax(Float64)
    times = 1
    while (now() < start + timeout) || (times <= min_calls)
        runtime = @elapsed(fex())
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
    return fex, gettime(fex)
end

function all_pmem_time(fex, args, profile_data)
    backend = fex.ex.backend

    # Get timing for All PMEM
    for fn_node in fex.ex.ngraph_function
        hasprofile(fn_node) || continue

        # Check the output tensors of this node can live in PMEM. If so, assign them there
        for tensor in nGraph.output_descriptors(fn_node)
            tensor_name = nGraph.get_name(tensor)
            if in(Runner.PMEM, profile_data.tensors[tensor_name].locations)
                nGraph.make_persistent(tensor)
            end
        end
    end
    fex = nGraph.recompile(fex)
    pmem_time = gettime(fex)

    return fex, pmem_time
end

_base_stats() = (
    # Runtimes
    predicted_runtimes = Float64[],
    actual_runtimes = Float64[],
    kernel_times = Vector{Any}[],
    move_time = Float64[],

    # Tensor Sizes
    io_sizes = Ref(0),
    default_alloc_size = Ref(0),
    dram_limits = Int64[],
    dram_alloc_size = Int64[],
    pmem_alloc_size = Int64[],
)

"""
    compare(f, opt_iter; kw...)

* `f`: A constructor function `f() -> fex, args` returning a `FluxExecutable` and a tuple
    of arguments to be passed to the executable.

* `opt_iter`: An iterator returning optimization arguments that will be passed to `factory`.

Keywords
--------

* `cache`: A cache for kernel timings. Defaults to `CPUKernelCache(BASE_CACHE_PATH)`. That
    is, the default cache.

* `statspath`: An optional file path to saved stats. If this is given, any DRAM limits
    already in the cached stats will be skipped on this profiling run.
"""
function compare(f, opt_iter, ctx = OnlyIntermediate(); 
                 cache = CPUKernelCache(BASE_CACHE_PATH), 
                 statspath = nothing,
                 skip_run = false,
    )
    if (isnothing(statspath) || !ispath(statspath)) 
        stats = _base_stats()
        initialize!(stats, f)
    else
        stats = deserialize(statspath)
    end

    for (index, opt) in enumerate(opt_iter)
        println("Processing $index of $(length(opt_iter))")

        # Use an inner function so that the FluxExecutable (and thus ngraph executable)
        # go out of scope and are thus elegible for garbage collection.
        #
        # Further, invoke the GC before calling this function.
        #
        # This will hopefully cleanup any previous Executables and the large memory buffers
        # associated with them.
        GC.gc()
        _compare!(stats, f, opt, ctx; cache = cache, skip_run = skip_run)
        isnothing(statspath) || serialize(statspath, stats)

        if !skip_run
            @info """
            Predicted Run Time: $(last(stats.predicted_runtimes))
            Actual Run Time: $(last(stats.actual_runtimes))
            """
        end
    end

    return stats
end

function initialize!(stats, f)
    # Instantiate the function
    fex, args = f()

    io_sizes = sum(sizeof, input_tensors(fex)) + sum(sizeof, output_tensors(fex))
    stats.io_sizes[] = io_sizes
    stats.default_alloc_size[] = nGraph.get_temporary_pool_size(fex.ex.ngraph_function)
    return nothing
end

function _compare!(stats, f, opt, ctx; skip_run = false, kw...)
    fex, args, frame, _metadata = factory(f, opt, ctx; skip_run = skip_run, kw...)

    skip = in(limit(frame.modeltype), stats.dram_limits)

    # Get the predicted run time and then the actual run time
    if !skip 
        push!(stats.predicted_runtimes, Runner.predict(frame))
        push!(stats.dram_limits, limit(frame.modeltype))
        push!(stats.dram_alloc_size, nGraph.get_temporary_pool_size(fex.ex.ngraph_function))
        push!(stats.pmem_alloc_size, nGraph.get_pmem_pool_size(fex.ex.ngraph_function))
        push!(stats.move_time, estimate_move_time(fex, frame))

        if !skip_run
            push!(stats.actual_runtimes, gettime(fex))
            push!(stats.kernel_times, read_timing_data(fex.ex.ngraph_function))
        end

    end

    nGraph._cleanup(fex.ex)
    return nothing
end

#####
##### Intraction methods with the `rettuple` from `compare`
#####

dc(x) = all(isequal(Runner.DRAM), x)
pmem_count(x) = count(isequal(Runner.PMEM), x)

function gettimings(data)
    timings = NamedTuple[]

    for node in data.nodes
        hasprofile(node) || continue
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

#####
##### Compare the running times of a function with the predicted runtime.
#####
function compare_kernel_times(fex::nGraph.FluxExecutable, data::ProfileData)
    kernel_times = read_timing_data(fex.ex.ngraph_function)
    results = []

    # Iterate through the kernels - find kernels with timing parameter, get their time,
    # and then find what the expected runtime is.
    for op in fex.ex.ngraph_function
        op_wrapped = NodeWrapper(op)
        if !hasprofile(op_wrapped) || description(op_wrapped) == "Move"
            continue
        end

        op_name = name(op_wrapped)
        config = getconfig(op)

        # Get the actual run time.
        index = findfirst(x -> x["name"] == op_name, kernel_times)
        actual_runtime = kernel_times[index]["dur"]

        # Get the expected run time
        index = findfirst(isequal(op_wrapped), nodes(data))
        expected_time = nodes(data, index).timings[config]

        push!(results, (
            name = op_name,
            config = config,
            actual = actual_runtime,
            expected = expected_time,
        ))
    end
    return results
end
