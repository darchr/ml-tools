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
#   Question: How do we tell the difference between different input and output layouts?
#   Answer: For now, lets not worry about tracking the format across runs, we'll just
#       reprofile as needed.
"""
    profile(fex::nGraph.FluxExecutable)

Profile all of the operations in `fex`.
"""
function profile(fex::nGraph.FluxExecutable; cache = nothing)
    # Go through each node
    # Create new parameters with the same input and outputs sizes
    # Call `copy_with_new_args` on the node in question with the new parameters
    # Swip the input and output tensor layouts from the node in question
    f = fex.ex.ngraph_function 

    for op in f
        sub_fn, copied_op = extract(op)
    end
end

function extract(node::nGraph.Node; backend = nGraph.Backend())
    # Create parameters for the inputs
    params = nGraph.Node[]
    for i in 1:nGraph.get_input_size(node)
        A = rand(nGraph.get_input_element_type(node, i), nGraph.get_input_shape(node, i)...)
        push!(params, nGraph.parameter(A))
    end

    # Do the conversion to the correct inputs
    converters = nGraph.Node[]  
    for i in 1:nGraph.get_input_size(node)
        push!(converters, nGraph.convert_layout_to(params[i], node, i))
    end

    # Copy the node with the `converters` arguments
    copied_node = nGraph.copy_with_new_args(node, converters)
    
    # Compile the new function
    inputs = nGraph.ParameterVector(params) 
    outputs = nGraph.NodeVector((copied_node,))
    return nGraph.compile(backend, inputs, outputs), copied_node
end
