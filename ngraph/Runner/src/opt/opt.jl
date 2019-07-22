# Sub project for taking a set of profiled data and building a JuMP model forming some
# optimization problem over that data.
#
# The main initial goal is to
# - Minimize the sum of kernel execution times
# - By assigning the locations of live intermediate tensors to either DRAM or PMEM
# - With a fixed memory budget of live tensors in DRAM
#
# However, we would like the framework to be flexible enough to allow swapping in of
# different:
#
# - Models for kernel execution times
# - High level problem descriptions
# - Retain the ability to insert "move" nodes and perform more complicated passes.
#
# #####
# ##### Initial Setup
# #####
#
# For just the initial formulation, we need the following pipeline:
#
# - Base data structure will be a vector of nGraph ops in `ordered_ops` structure,
#   which is the order that they are executed by the nGraph runtime.
#
# - Get a list of all intermediate tensors and sizes.
#   Each tensor can either live in DRAM or PMEM, so we need to generate JuMP variables
#   accordingly.
#
# - Do a liveness analysis to determine where tensors begin and when they go out of
#   scope.
#
# - Iterate through each op in the nGraph ops. For each op, generate
#
#   1. A capacity constraint on the number of live tensors in DRAM.
#   2. Generate a `gadget` to encode the running time of the kernel given the locations
#      of its inputs and outputs.
#   3. Add the results of this gadget to the global objective function, which will be
#      to minimize the sum of active running times.
#
# To accomplish this, we need to pass around a JuMP `Model` which we may progressively
# add variables and constraints to.
#
# To sequentially build the objective function, we can have a JuMP `expression`
# (http://www.juliaopt.org/JuMP.jl/v0.19.0/expressions/) which we update with the
# `add_to_expression!` function at each node in the graph.

# Struct to be passed around since all these items are generally used together anyways.
mutable struct Frame{T}
    modeltype::T
    model::JuMP.Model
    profile_data::ProfileData
end

limit(F::Frame) = limit(F.modeltype)

JuMP.optimize!(F::Frame) = optimize!(F.model)

include("affinity.jl")
include("ilp.jl")
include("inspect.jl")
include("configure.jl")
include("modnn/modnn.jl")
include("numa/numa.jl")

function actualize(backend, func; nkw...)
    f, args, kw = func()
    return nGraph.compile(backend, f, args...; kw..., nkw...)
end

"""
    factory(::nGraph.Backend{nGraph.CPU}, func, opt::AbstractOptimizer; search_ratio = true)
"""
function factory(
        backend::nGraph.Backend{nGraph.CPU}, 
        func, 
        opt::AbstractOptimizer; 
        search_ratio = true,
        max_iters = 15
    )

    # Just return the inner factory if we aren't interesting in performing a binary search
    # for the actual ratio to input that will return the desired ratio
    search_ratio || return _factory(backend, func, opt)

    # Perform a binary search
    fex, args = _factory(backend, func, opt)   

    # If we're within the desired tolerance, just return like normal
    checkmargin(fex, opt) && return (fex, args...)

    # Time to perform a binary search!
    if getratio(fex) < getratio(opt)
        # fex has less PMEM than needed
        lb = 1 // 0
        ub = getratio(opt)
    else
        # fex has more PMEM than needed
        lb = getratio(opt)
        ub = 0 // 1
    end

    for i in 1:max_iters
        @info """
        Desired Ratio: $(convert(Float64, getratio(opt)))
        Actual Ratio: $(convert(Float64, getratio(fex)))
        """

        r = (lb + ub) / 2  
        fex, args = _factory(backend, func, _optimizer(opt, r))
        checkmargin(fex, opt) && return (fex, args...)

        if getratio(fex) < getratio(opt)
            ub = r
        else
            lb = r
        end
    end
    error("Could not find a solution for ratio $(getratio(opt))")
end


function _factory(backend::nGraph.Backend{nGraph.CPU}, func, opt)
    # Unpack and compile the function
    fex = actualize(backend, func)
    #apply_affinity_heuristic!(fex.ex.ngraph_function)

    data = profile(fex)
    modeltype = opt(data)

    # Some data structures for keeping track of modeling and optimization time.
    creation_times = Float64[]  
    optimization_times = Float64[]

    # Iterate until convergence
    while true
        # Optimize the function
        creation_time = @elapsed(frame = create_model(modeltype, data))
        optimization_time = @elapsed(optimize!(frame))
        fex, _metadata = configure!(fex, frame)

        push!(creation_times, creation_time)
        push!(optimization_times, optimization_time)

        # Deal with fragmentation
        if exceeds_limit(fex, modeltype)
            @info """
            Limit Exceeded
            Limit: $(maxlimit(modeltype))
            Actual: $(convert(Int, nGraph.get_temporary_pool_size(fex.ex.ngraph_function)))
            """

            modeltype = update(modeltype, frame.profile_data)

            # Update the flux executable
            fex = actualize(backend, func)
            #apply_affinity_heuristic!(fex.ex.ngraph_function)

            data = profile(fex)
        # Adjust ratio if outside of of the desired bounds
        else
            frame.profile_data = profile(fex)

            metadata = Dict(
                :metadata => _metadata,
                :creation_times => creation_times,
                :optimization_times => optimization_times,
            )

            return fex, frame, metadata
        end
    end
end

#####
##### GPU factory
#####
function _factory(backend::nGraph.Backend{nGraph.GPU}, func, opt)
    # Get the function, arguments, and keyword arguments from the provided function
    f, args, kw = func()

    # add a callback that will populate a reference to a `ProfileData` type
    frame_ref = Ref{Frame}()
    limits_ref = Ref{Vector{Int}}() 

    #A callback that profiles the ngraph function
    function cb(f::nGraph.NFunction)
        # Do some minor editing the order of nodes in the graph to hopefully yield slightly
        # better memory characteristics
        apply_affinity_heuristic!(f)

        data = profile(f, backend)

        # Initialize the node dram limits if needed
        if !isdefined(limits_ref, :x)
            limits_ref[] = [6000 for _ in 1:length(nodes(data))]
        end

        modeltype = asynchronous(limits_ref[], 12000, 12000, 12000, 12000)
        #modeltype = synchronous(limits_ref[], 12000, 12000)

        frame = create_model(modeltype, data)
        optimize!(frame)
        #list_overlaps(frame)
        tensor_map = configure!(f, frame)

        frame_ref[] = frame
        return nothing
    end

    # Defrag callback - if a function needs defragging, throws a `GPUExit` exception to
    # avoid nGraph trying to allocate too much GPU memory
    function defrag(f::nGraph.NFunction)
        if exceeds_limit(f, frame_ref[].modeltype)
            # This is pretty ugly - sorry about that.
            modeltype = update(frame_ref[].modeltype, profile(f, backend))
            limits_ref[] = modeltype.dram_limits

            throw(GPUExit())
        end
    end

    # Compile the function to a ngraph executable
    local fex
    retry = true
    while retry
        retry = false

        # Setup callbacks
        #
        # If the function needs defragging, a `GPUExit` exception will be thrown and we
        # will have to try again.
        gpu_callbacks = GPUCallback()
        callback!(gpu_callbacks, cb)
        callback!(gpu_callbacks, defrag)

        try
            fex = nGraph.compile(
                backend, 
                f, 
                args...;
                callback = gpu_callbacks, 
                emit_timing = true, 
                kw...
            )
        catch e
            isa(e, GPUExit) || rethrow(e)
            retry = true
        end
    end

    return fex, frame_ref[]
end

