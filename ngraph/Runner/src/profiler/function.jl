# Timing methods for the whole function

function gettime(fex::nGraph.FluxExecutable; timeout = Second(10), min_calls = 2)
    start = now()
    mintime = typemax(Float64)
    times = 1
    while (now() < start + timeout) || (times <= min_calls)
        @info "Running Function"
        runtime = @elapsed(fex())
        @info "Done Running Function"
        mintime = min(mintime, runtime)
        times += 1
    end
    return mintime
end

_base_stats() = (
    io_size = Ref(0),
    default_alloc_size = Ref(0),     
    runs = Vector{NamedTuple}(),
)
# _base_stats() = (
#     # Runtimes
#     predicted_runtimes = Float64[],
#     actual_runtimes = Float64[],
#     kernel_times = Vector{Any}[],
#     move_time = Float64[],
# 
#     # Tensor Sizes
#     io_sizes = Ref(0),
#     default_alloc_size = Ref(0),
#     dram_limits = Int64[],
#     dram_alloc_size = Int64[],
#     pmem_alloc_size = Int64[],
# )

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
function compare(f, opt; 
                 cache = CPUKernelCache(BASE_CACHE_PATH), 
                 statspath = nothing,
                 skip_run = false,
                 skip_configure = false
    )
    if (isnothing(statspath) || !ispath(statspath)) 
        stats = _base_stats()
        initialize!(stats, f)
    else
        stats = deserialize(statspath)
    end

    # Use an inner function so that the FluxExecutable (and thus ngraph executable)
    # go out of scope and are thus elegible for garbage collection.
    #
    # Further, invoke the GC before calling this function.
    #
    # This will hopefully cleanup any previous Executables and the large memory buffers
    # associated with them.
    GC.gc()
    _compare!(stats, f, opt; cache = cache, skip_run = skip_run, skip_configure = skip_configure)
    isnothing(statspath) || serialize(statspath, stats)

    if !skip_run
        @info """
        Predicted Run Time: $(last(stats.runs.predicted_runtime))
        Actual Run Time: $(last(stats.runs.actual_runtime))
        """
    end

    return stats
end

function initialize!(stats, f)
    # Instantiate the function
    fex, args = f()

    stats.io_size[] = sum(sizeof, input_tensors(fex)) + sum(sizeof, output_tensors(fex))
    stats.default_alloc_size[] = nGraph.get_temporary_pool_size(fex.ex.ngraph_function)
    return nothing
end

function _compare!(stats, f, opt; skip_run = false, skip_configure = false, kw...)
    fex, args, frame, _metadata = factory(f, opt; skip_configure = skip_configure, kw...)
    GC.gc()

    seen_limits = getproperty.(stats.runs, :dram_limit) 
    skip = in(limit(frame.modeltype), seen_limits)

    # Get the predicted run time and then the actual run time
    if !skip 
        nt = (
            predicted_runtimes = Runner.predict(frame),
            dram_limit = limit(frame.modeltype),
        )

        if !skip_configure
            nt_new = (
                # Some statistics on nodes and tensors
                num_move_nodes = count_moves(fex),
                num_kernels = count_nodes(frame.profile_data),
                num_input_tensors = count_tensor_inputs(frame.profile_data),
                num_output_tensors = count_tensor_outputs(frame.profile_data),
                num_dram_input_tensors = count_tensor_dram_inputs(frame.profile_data),
                num_dram_output_tensors = count_tensor_dram_outputs(frame.profile_data),

                # Info on global allocations
                dram_alloc_size = nGraph.get_temporary_pool_size(fex.ex.ngraph_function),
                pmem_alloc_size = nGraph.get_pmem_pool_size(fex.ex.ngraph_function),
                move_time = estimate_move_time(fex, frame),
            )
            nt = merge(nt, nt_new)
        end

        if !skip_run
            nt_new = (
                actual_runtime = gettime(fex),
                kernel_times = read_timing_data(fex.ex.ngraph_function)
            )
            nt = merge(nt, nt_new)
        end

        push!(stats.runs, nt)
    end

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
            node = op_wrapped,
        ))
    end
    return results
end

#####
##### Calibration
#####

# Sometimes, after profiling, the results from the pure profiling step are wildly 
# inaccurate.
#
# In such cases, we may have to perform a post-per-node profiling step where we execute the
# whole graph and customize our nodes times for that graph.
_err(expected, actual) = abs(expected /1E6 - actual) / actual
function calibrate(f, opt; 
        cache = CPUKernelCache(BASE_CACHE_PATH),
        tol = 0.10,
        max_iterations = 20,
        α = 1.0,
    )

    # Enter loop
    fex, args, frame, _metadata = factory(f, opt; cache = cache)
    expected_runtime = Runner.predict(frame)
    actual_runtime = gettime(fex)

    err = _err(expected_runtime, actual_runtime)

    iterations = 0
    while err > tol
        # Debug info
        iterations += 1
        println("Performing Calibration Iteration $iterations")
        println("Error: $err")

        # Get the individual node times. Update the state of any entry in the cache.
        kernel_times = compare_kernel_times(fex, frame.profile_data)
        kernels_updated = 0

        # Create a local cache - we'll update the global cache with the average.
        local_cache = Dict{keytype(cache.cache), Vector{Float64}}()
        for kernel_time in kernel_times
            expected = minimum(kernel_time.expected)
            actual = kernel_time.actual
            if _err(expected, actual) > tol 
                config = kernel_time.config
                params = CPUKernelParams(kernel_time.node)
                # Update and save the cache
                vec = get!(local_cache, (params, config), Float64[])
                push!(vec, actual)
                save(cache)
                kernels_updated += 1
            end
        end

        for (k,v) in local_cache
            cache[k] = mean(v)
        end

        println("Updated $kernels_updated kernels on this iteration")

        iterations > max_iterations && break 

        # Try again
        fex, args, frame, _metadata = factory(f, opt; cache = cache)
        expected_runtime = Runner.predict(frame)
        actual_runtime = gettime(fex)

        err = _err(expected_runtime, actual_runtime)
    end
    println("Final Error: $err")
    return iterations
end
