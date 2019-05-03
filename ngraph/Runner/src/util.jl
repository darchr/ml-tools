function _find(f, itr)
    idx = findfirst(f, itr)
    isnothing(idx) && error()
    return idx
end

function _producer(tensor::TensorWrapper, nodes::Vector{NodeWrapper})
    idx = _find(x -> in(tensor, outputs(x)), nodes)
    return nodes[idx]
end

"""
    isarg(fex::nGraph.FluxExecutable, t::TensorWrapper) -> Bool

Return `true` if `t` is an input tensor for `fex`.
"""
function isarg(fex::nGraph.FluxExecutable, t::TensorWrapper)
    input_nodes = NodeWrapper.(nGraph.get_parameters(fex.ex.ngraph_function))

    for node in Iterators.take(input_nodes, length(fex.inputs))
        in(t, outputs(node)) && return true
    end
    return false
end

function isresult(fex::nGraph.FluxExecutable, t::TensorWrapper)
    output_nodes = NodeWrapper.(nGraph.get_results(fex.ex.ngraph_function))

    for node in output_nodes
        in(t, outputs(node)) && return true
    end
    return false
end

"""
    isarg(fex::nGraph.FluxExecutable, t::TensorWrapper) -> Bool

Return `true` if `t` is a parameter tensor for `fex`.
"""
function isparam(fex::nGraph.FluxExecutable, t::TensorWrapper)
    input_nodes = NodeWrapper.(nGraph.get_parameters(fex.ex.ngraph_function))

    for node in input_nodes
        in(t, outputs(node)) && return true
    end
    return false
end

function findpair(fex::nGraph.FluxExecutable, t::TensorWrapper)
    # Get the input number of this tensor.
    #
    # Subtract off the number of input arguments to get its position in the optimizer 
    # parameter list
    input_nodes = NodeWrapper.(nGraph.get_parameters(fex.ex.ngraph_function))
    idx = _find(x -> in(tensor, outputs(x)), input_nodes) - length(fex.inputs)

    offset = length(fex.outputs) + length(fex.secondary_outputs) + idx
    pair_node = NodeWrapper(nGraph.get_results(fex.ex.ngraph_function)[idx])

    @assert length(outputs(pair_node)) == 1
    return first(outputs(pair_node))
end

function get_exe_input(fex::nGraph.FluxExecutable, t::TensorWrapper)
    input_nodes = NodeWrapper.(nGraph.get_parameters(fex.ex.ngraph_function))
    idx = _find(x -> in(tensor, outputs(x)), input_nodes)
    return collect(nGraph._splat_inputs(fex.optimizer))[idx]
end

function get_exe_output(fex::nGraph.FluxExecutable, t::TensorWrapper)
    output_nodes = NodeWrapper.(nGraph.get_results(fex.ex.ngraph_function))
    idx = _find(x -> in(tensor, outputs(x)), output_nodes)
    return collect(nGraph._splat_outputs(fex.optimizer))[idx]
end
