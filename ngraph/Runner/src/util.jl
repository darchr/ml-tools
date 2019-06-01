function _find(f, itr)
    idx = findfirst(f, itr)
    isnothing(idx) && error()
    return idx
end

function _producer(tensor::TensorWrapper, nodes::Vector{NodeWrapper})
    idx = _find(x -> in(tensor, outputs(x)), nodes)
    return nodes[idx]
end

function _lastuser(tensor::TensorWrapper, nodes::Vector{NodeWrapper})
    idx = _find(x -> in(tensor, outputs(x)), reverse(nodes))
    return nodes[end + 1 - idx]
end

function input_tensors(fex::nGraph.FluxExecutable)
    params = NodeWrapper.(nGraph.get_parameters(fex.ex.ngraph_function))
    return Iterators.flatten(outputs.(params))
end

function output_tensors(fex::nGraph.FluxExecutable)
    params = NodeWrapper.(nGraph.get_results(fex.ex.ngraph_function))
    return Iterators.flatten(inputs.(params))
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

function isparam(fex::nGraph.FluxExecutable, n::NodeWrapper)
    return in(n, NodeWrapper.(nGraph.get_parameters(fex.ex.ngraph_function)))
end

function isresult(fex::nGraph.FluxExecutable, t::TensorWrapper)
    output_nodes = NodeWrapper.(nGraph.get_results(fex.ex.ngraph_function))

    for node in output_nodes
        in(t, outputs(node)) && return true
    end
    return false
end

function isresult(fex::nGraph.FluxExecutable, n::NodeWrapper)
    return in(n, NodeWrapper.(nGraph.get_results(fex.ex.ngraph_function)))
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

function get_exe_input(fex::nGraph.FluxExecutable, tensor::TensorWrapper)
    input_nodes = NodeWrapper.(nGraph.get_parameters(fex.ex.ngraph_function))
    idx = _find(x -> in(tensor, outputs(x)), input_nodes)
    return collect(nGraph._splat_inputs(fex))[idx]
end

function get_exe_output(fex::nGraph.FluxExecutable, tensor::TensorWrapper)
    output_nodes = NodeWrapper.(nGraph.get_results(fex.ex.ngraph_function))
    idx = _find(x -> in(tensor, outputs(x)), output_nodes)
    return collect(nGraph._splat_outputs(fex))[idx]
end

function make_persistent(fex::nGraph.FluxExecutable, data::ProfileData, tensor::TensorWrapper)
    # Check if this is an IO tensor, need to take an extra step if that is the case.
    if isparam(fex, tensor)
        nGraph.make_persistent!(get_exe_input(fex, tensor))
    end 

    if isresult(fex, tensor)
        nGraph.make_persistent!(get_exe_output(fex, tensor))
    end
    nGraph.make_persistent(unwrap(tensor))
end

make_persistent(tensor::TensorWrapper) = nGraph.make_persistent(unwrap(tensor))
make_volatile(tensot::TensorWrapper) = nGraph.make_volatile(unwrap(tensor))

function make_volatile(fex::nGraph.FluxExecutable, data::ProfileData, tensor::TensorWrapper)
    nGraph.make_volatile(unwrap(tensor))
end
