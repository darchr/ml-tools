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

include("ilp.jl")
include("modnn/modnn.jl")

"""
- `f`: Function `() -> fex, args`: Return `FluxExecutable` and args.

- `opt`: Function `ProfileData -> modeltype <: ModelType`.
"""
function factory(f, opt)
    fex, args = f()
    data = profile(fex)
    modeltype = opt(data)

    # Clone the underlying ngraph function to be able to reconstruct it with the 
    # same order nodes.
    #cloned_function = copy(fex.ex.function_copy)  

    # Iterate until convergence
    while true
        # Optimize the function
        frame = create_model(modeltype, data)
        optimize!(frame)
        fex, _metadata = configure!(fex, frame) 
     
        if exceeds_limit(fex, modeltype)
            @info """
            Limit Exceeded
            Limit: $(maxlimit(modeltype))
            Actual: $(convert(Int, nGraph.get_temporary_pool_size(fex.ex.ngraph_function)))
            """

            modeltype = update(modeltype, fex, frame.profile_data)

            # Update the flux executable
            fex, args = f()
            data = profile(fex) 
        else
            return fex, args, frame, _metadata
        end
    end
end

function gpu_factory(func, do_opt = true)
    # Get the function, arguments, and keyword arguments from the provided function
    f, args, kw = func()

    # add a callback that will populate a reference to a `ProfileData` type
    dataref = Ref{ProfileData{nGraph.GPU, Union{Float64,_ALGO_TUPLE}}}()
    backend = nGraph.Backend("GPU")

    # A callback that profiles the ngraph function
    function cb(f::nGraph.NFunction) 
        # Capture `dataref` and `backend`
        data = profile(f, backend)

        modeltype = synchronous([400 for _ in 1:length(nodes(data))], 16000, 16000)
        frame = create_model(modeltype, data)
        optimize!(frame)
        tensor_map = configure!(f, frame)

        dataref[] = data
        return nothing
    end

    # Compile the function to a ngraph executable
    if (do_opt)
        fex = nGraph.compile(backend, f, args...; callback = cb, emit_timing = true, kw...)
        return fex, dataref[]
    else
        fex = nGraph.compile(backend, f, args...; emit_timing = true, kw...)
        return fex, nothing
    end

    #return fex, dataref[]
end

#####
##### Utility Functions
#####

function find_vertex(g, f)
    iter = filter(v -> f(g,v), collect(vertices(g)))
    # Make sure we only have one match
    @assert length(iter) == 1
    return first(iter)
end

function find_edge(g, f)
    iter = filter(e -> f(g,e), collect(edges(g)))

    # Make sure we only have one match
    @assert length(iter) == 1
    return first(iter)
end

approx_one(x) = isapprox(x, one(x); atol = 1e-3)
approx_one(x::JuMP.VariableRef) = approx_one(value(x))

"""
    insert_move_node!(producer, index, consumers) -> nGraph.Node

Insert an nGraph `move` node between `producer` and all `consumers`. Return the newly 
created node.
"""
function insert_move_node!(producer::NodeDescriptor, index, consumers::Vector{NodeDescriptor}, consumer_inputs)
    move_node = nGraph.move(nGraph.Node(producer), index)
    for (consumer, input) in zip(consumers, consumer_inputs)
        nGraph.splice(nGraph.Node(producer), index, nGraph.Node(consumer), input, move_node)
    end
    
    return NodeDescriptor(move_node)
end

function insert_moveasync_node!(
        producer::NodeDescriptor, 
        index, 
        consumers, 
        consumer_inputs, 
        concurrent
    )

    move_node = nGraph.moveasync(nGraph.Node(producer), index, nGraph.Node(concurrent))
    for (consumer, input) in zip(consumers, consumer_inputs)
        nGraph.splice(nGraph.Node(producer), index, nGraph.Node(consumer), input, move_node)
    end
    
    return NodeDescriptor(move_node)
end
