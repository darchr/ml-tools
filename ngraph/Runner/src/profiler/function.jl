# Timing methods for the whole function
function gettime(fex::nGraph.FluxExecutable; timeout = Second(10), min_calls = 5)
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
    runs = Vector{Dict{Symbol,Any}}(),
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
function compare(
        func,
        opt,
        backend::nGraph.Backend;
        cache = CPUKernelCache(BASE_CACHE_PATH),
        statspath = nothing,
    )

    if (isnothing(statspath) || !ispath(statspath))
        stats = _base_stats()
        initialize!(stats, func, backend)
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
    _compare!(
        stats,
        f,
        opt,
        backend;
        cache = cache,
        skip_run = skip_run,
        skip_configure = skip_configure
    )

    isnothing(statspath) || serialize(statspath, stats)
    if !skip_run
        @info """
        Predicted Run Time: $(last(stats.runs)[:predicted_runtime])
        Actual Run Time: $(last(stats.runs)[:actual_runtime])
        """
    end

    return stats
end

function initialize!(stats, func, backend)
    # Instantiate the function
    fex = actualize(backend, func)

    stats.io_size[] = sum(sizeof, input_tensors(fex)) + sum(sizeof, output_tensors(fex))
    stats.default_alloc_size[] = nGraph.get_temporary_pool_size(fex.ex.ngraph_function)
    return nothing
end

function _compare!(stats, f, opt, backend; skip_run = false, skip_configure = false, kw...)
    fex, args, frame, _metadata = factory(backend, f, opt; kw...)
    GC.gc()
    data = frame.profile_data

    # Get the predicted run time and then the actual run time
    if !skip
        nt = Dict(
            :predicted_runtime => Runner.predict(frame),
            :dram_limit => maxlimit(frame.modeltype),
            :tensor_size_map => Dict(nGraph.name(t) => sizeof(t) for t in tensors(data)),
            :config_map => Dict(nGraph.name(n) => getconfig(nGraph.Node(n)) for n in nodes(data)),
        )

        if !skip_configure
            nt_new = Dict(
                # Some statistics on nodes and tensors

                # Number of move nodes plus bytes moved around
                :num_move_nodes => count(_move_filter(), nodes(data)),
                :num_pmem_move_nodes => count(_move_filter(PMEM), nodes(data)),
                :num_dram_move_nodes => count(_move_filter(DRAM), nodes(data)),

                :bytes_moved => _count(inputs, sizeof, data; filt = _move_filter()),
                :bytes_moved_pmem => _count(inputs, sizeof, data; filt = _move_filter(PMEM)),
                :bytes_moved_dram => _count(inputs, sizeof, data; filt = _move_filter(DRAM)),

                :num_async_move_nodes => count(_async_filter(), nodes(data)),
                :num_pmem_async_move_nodes => count(_async_filter(PMEM), nodes(data)),
                :num_dram_async_move_nodes => count(_async_filter(DRAM), nodes(data)),

                :bytes_async_moved => _count(inputs, sizeof, data; filt = _async_filter()),
                :bytes_async_moved_pmem => _count(inputs, sizeof, data; filt = _async_filter(PMEM)),
                :bytes_async_moved_dram => _count(inputs, sizeof, data; filt = _async_filter(DRAM)),

                # Total number of kernels
                :num_kernels => count(hasprofile, nodes(data)),
                :num_input_tensors => _count(inputs, data; filt = hasprofile),
                :num_output_tensors => _count(outputs, data; filt = hasprofile),

                :num_dram_input_tensors => _count(
                    x -> filter(!nGraph.is_persistent, inputs(x)),
                    data; filt = hasprofile
                ),
                :num_dram_output_tensors => _count(
                    x -> filter(!nGraph.is_persistent, outputs(x)),
                    data; filt = hasprofile
                ),

                # Get the sizes of the input and output tensors
                :bytes_input_tensors => _count(inputs, sizeof, data; filt = hasprofile),
                :bytes_output_tensors => _count(outputs, sizeof, data; filt = hasprofile),

                :bytes_dram_input_tensors => _count(
                    x -> filter(!nGraph.is_persistent, inputs(x)),
                    sizeof,
                    data;
                    filt = hasprofile
                ),
                :bytes_dram_output_tensors => _count(
                    x -> filter(!nGraph.is_persistent, outputs(x)),
                    sizeof,
                    data;
                    filt = hasprofile
                ),

                # Info on global allocations
                :dram_alloc_size => nGraph.get_temporary_pool_size(fex.ex.ngraph_function),
                :pmem_alloc_size => nGraph.get_pmem_pool_size(fex.ex.ngraph_function),
                :move_time => estimate_move_time(fex, frame),
            )
            nt = merge(nt, nt_new)
        end

        if !skip_run
            nt_new = Dict(
                :actual_runtime => gettime(fex),
                :kernel_times => read_timing_data(fex.ex.ngraph_function)
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
        op_wrapped = NodeDescriptor(op)
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
        expected_time = gettime(data, nodes(data, index), config)

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
