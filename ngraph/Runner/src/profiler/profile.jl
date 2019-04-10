# Profile the running times of kernels.
#
# Steps that need to be performed
#
# 1. Get the ops in the executable. Clone each of the ops into their own nGraph
#   function.
#
# 2. For each of the ops, we also have to capture the input and output tensor layouts
#   for the op in order to get accurate timing.
#
#   As far as I can tell, if a CPU op is annotated as "use_mkldnn_kernel", then the
#   input and output layout will always be the same. Thus, to do the correct
#   input/output layout conversion, we just have to check if the node we are copying is
#   annotated as mkldnn and make sure we annotate the new node as such.

include("cache.jl")
include("function.jl")

"""
    profile(fex::nGraph.FluxExecutable; cache, saver)

Profile all of the operations in `fex`.

Keyword Arguments
-----------------
* `cache`: A cache to serve running times if a kernel has already been profiled

* `saver`: An optional callable that will save the cache each time it is updated
    to provide stability against problems. Must be callable as `saver(cache)`.
"""
function profile(fex::nGraph.FluxExecutable; cache = EmptyCache(), saver = nothing)
    # Setup stuff
    #setup_profiling()
    #setup_pmem()

    backend = fex.ex.backend

    # Go through each node
    # Create new parameters with the same input and outputs sizes
    # Call `copy_with_new_args` on the node in question with the new parameters
    # Swip the input and output tensor layouts from the node in question
    f = fex.ex.ngraph_function
    data = ProfileData(f)

    # Get all the configurations we are interested in for this run.
    # Need to make a MOVE node in order to control IO configurations.
    all_configs = get_configs(data, f)
    # Convert the configs to a dictionary mapping node name to configs for easier
    # management
    config_dict = Dict{String, Vector{IOConfig}}()
    for config in all_configs
        v = get!(config_dict, first(config), IOConfig[])
        push!(v, last(config))
    end

    @showprogress 1 for (index, op) in enumerate(f)
        # Skip unneeded ops
        keep(op) || continue
        op_name = nGraph.name(op)
        op_data = data.nodes[index]

        # Get the configs to run for this node
        configs = config_dict[op_name]

        # Before we build a sub-function, get all of the cached ops.

        cached_configs = IOConfig[]
        kernel_params = CPUKernelParams(op) 
        for config in configs 
            if haskey(cache, (kernel_params, config))
                op_data.timings[config] = [cache[(kernel_params, config)]]
                push!(cached_configs, config)
            end
        end

        # Abort if everything is cached
        length(cached_configs) == length(configs) && continue 

        # Extract a subgraph with just this op
        ex, inputs, outputs, copied_op = extract(op)

        # Profile the timings
        for config in filter(!in(cached_configs), configs)
            # setup the config
            _setup!(copied_op, config)

            # recompile the function to reflect the new config state
            ex = nGraph.recompile(backend, ex)
            function_name = nGraph.name(ex.ngraph_function)
            for _ in 1:5
                ex(inputs, outputs)
                record_time!(op_data, function_name, copied_op)
            end

            _cleanup!(copied_op)

            # Save the results to the cache. If a saver function is provided, call
            # it to backup the cache.
            cache[(kernel_params, config)] = minimum(op_data.timings[config])
            saver === nothing || saver(cache)
        end
    end

    return data
end

read_timing_data(fn::nGraph.NFunction) = read_timing_data(nGraph.name(fn))
read_timing_data(fn::AbstractString) = JSON.parsefile("$fn.timeline.json")["traceEvents"]

function record_time!(node_data, function_name, op)
    timings = read_timing_data(function_name)
    # Get the persistence config of this op
    config = getconfig(op)

    # Extract the timings and record it
    index = findfirst(x -> x["name"] == nGraph.name(op), timings)
    @assert index !== nothing

    push!(get!(node_data.timings, config, Float64[]), timings[index]["dur"])
end

function extract(node::nGraph.Node; backend = nGraph.Backend())
    # Create parameters for the inputs
    params = nGraph.Node[]
    for i in 1:nGraph.get_input_size(node)
        A = rand(nGraph.get_input_element_type(node, i), nGraph.get_input_shape(node, i)...)
        push!(params, nGraph.parameter(A))
    end

    # Insert layout conversion to match the mkldnn layouts in the original graph.
    links = nGraph.Node[] 
    for i in 1:nGraph.get_input_size(node)
        if nGraph.input_needs_conversion(node, i)
            push!(links, nGraph.convert_layout_to(params[i], node, i))
        else
            push!(links, params[i])
        end
    end

    # Copy the node with the newly created parameters
    copied_node = nGraph.copy_with_new_args(node, links)

    # Make sure we're using the same version of the node.
    nGraph.is_mkldnn(node) && nGraph.set_mkldnn(copied_node)

    # Compile the new function
    paramvector = nGraph.ParameterVector(params...)

    outputs = nGraph.Node[]
    if nGraph.get_output_size(copied_node) > 1
        for i in 1:nGraph.get_output_size(copied_node)
            push!(outputs, nGraph.get_output_element(copied_node, i))
        end
    else
        push!(outputs, copied_node)
    end

    # Get an result output for each output of the node
    nodevector = nGraph.NodeVector(outputs)

    # First, we compile the function
    ex = nGraph.compile(backend, paramvector, nodevector)

    # Then, we have to inspect the graph, find the nodes that do not have converted
    # inputs, and insert out synchronous move nodes so we can control the input/output
    # state of the node under test.
    #
    # But first, we have to find what happened to the original node and find it in the
    # new graph.
    local translated_node
    found = false
    for op in ex.ngraph_function
        # Line it up by description and input/output sizes.
        if nGraph.description(op) == nGraph.description(copied_node) &&
            nGraph.get_input_size(op) == nGraph.get_input_size(copied_node) &&
            nGraph.get_output_size(op) == nGraph.get_output_size(op)

            translated_node = op
            found = true
            break
        end
    end
    @assert found

    for input in nGraph.get_inputs(translated_node)
        if nGraph.description(input) == "Parameter"
            nGraph.splice(input, translated_node, nGraph.move(input))
        end
    end

    # Recompile the function, now with the move nodes.
    ex = nGraph.recompile(backend, ex)

    # Make these any to make them compatible with the inner call for nGraph.Executable
    input_tensors = Any[nGraph.Tensor(backend, x).ptr for x in params]
    output_tensors = Any[nGraph.Tensor(backend, x).ptr for x in outputs]

    return ex, input_tensors, output_tensors, translated_node
end
