# Timing methods for the whole function

function gettime(fex::nGraph.FluxExecutable, args; timeout = Second(15), min_calls = 3)
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

function _dram_time(fex, args)
    # Get timing for All DRAM
    backend = fex.ex.backend
    Runner._cleanup!(fex.ex.ngraph_function)
    fex = nGraph.recompile(backend, fex)
    return fex, gettime(fex, args)
end

function _pmem_time(fex, args, profile_data)
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
    fex = nGraph.recompile(backend, fex)
    pmem_time = gettime(fex, args)
    
    return fex, pmem_time
end

function compare(iter, fex::nGraph.FluxExecutable, args, profile_data)
    # Do a single call to warm up
    fex(args...)
    
    # Establish baseline DRAM and PMEM times
    fex, dram_time = _dram_time(fex, args)
    fex, pmem_time = _pmem_time(fex, args, profile_data)
    
    # Run each of the test functions
    predicted_runtimes = Float64[]
    actual_runtimes = Float64[]

    # Keep the parsed JSON of kernel timings for comparison with the predicted value
    kernel_times = Vector{Any}[]
    
    for (index, modeltype) in enumerate(iter)
        println("Processing $index of $(length(iter))")
        model = Runner.create_model(modeltype, profile_data)
        optimize!(model)
        fex = Runner.configure!(modeltype, fex, profile_data, model)
        
        # Get the predicted run time and then the actual run time
        push!(predicted_runtimes, Runner.predict(modeltype, model))
        push!(actual_runtimes, gettime(fex, args))
        push!(kernel_times, read_timing_data(fex.ex.ngraph_function))

        @info """
        Predicted Run Time: $(last(predicted_runtimes))
        Actual Run Time: $(last(actual_runtimes))
        """
    end

    # Prepare the return values
    rettuple = (
        dram_time = dram_time,
        pmem_time = pmem_time,
        predicted_runtimes = predicted_runtimes,
        actual_runtimes = actual_runtimes,
        kernel_times = kernel_times,
    )
    
    return fex, rettuple
end
