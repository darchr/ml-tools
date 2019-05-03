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
    pmem_time = gettime(fex, args)

    return fex, pmem_time
end

_base_stats() = (
    predicted_runtimes = Float64[],
    actual_runtimes = Float64[],
    dram_limits = Int64[],
    kernel_times = Vector{Any}[],
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
function compare(f, opt_iter; cache = CPUKernelCache(BASE_CACHE_PATH), statspath = nothing)
    stats = (isnothing(statspath) || !ispath(statspath)) ? _base_stats() : deserialize(statspath)

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
        _compare!(stats, f, opt; cache = cache)
        isnothing(statspath) || serialize(statspath, stats)

        @info """
        Predicted Run Time: $(last(stats.predicted_runtimes))
        Actual Run Time: $(last(stats.actual_runtimes))
        """
    end

    return stats
end

function _compare!(stats, f, opt; kw...)
    fex, args, frame, _metadata = factory(f, opt; kw...)

    skip = in(limit(frame.modeltype), stats.dram_limits)

    # Get the predicted run time and then the actual run time
    if !skip 
        push!(stats.predicted_runtimes, Runner.predict(frame))
        push!(stats.actual_runtimes, gettime(fex, args))
        push!(stats.dram_limits, limit(frame.modeltype))
        push!(stats.kernel_times, read_timing_data(fex.ex.ngraph_function))
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
