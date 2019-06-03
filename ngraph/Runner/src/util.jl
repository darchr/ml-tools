"""
    findonly(f, itr)

Find the first element of `x` iterator `itr` where `f(x) == true` and make sure that `x`
is the only element of `itr` with this property.

Return the index of `x`.
"""
function findonly(f, itr)
    idx = findfirst(f, itr)
    isnothing(idx) && error()
    return idx
end

function _producer(tensor::TensorDescriptor, nodes::Vector{NodeDescriptor})
    idx = findonly(x -> in(tensor, outputs(x)), nodes)
    return nodes[idx]
end

function _lastuser(tensor::TensorDescriptor, nodes::Vector{NodeDescriptor})
    idx = findonly(x -> in(tensor, outputs(x)), reverse(nodes))
    return nodes[end + 1 - idx]
end

function input_tensors(fex::nGraph.FluxExecutable)
    params = NodeDescriptor.(nGraph.get_parameters(fex.ex.ngraph_function))
    return Iterators.flatten(outputs.(params))
end

function output_tensors(fex::nGraph.FluxExecutable)
    params = NodeDescriptor.(nGraph.get_results(fex.ex.ngraph_function))
    return Iterators.flatten(inputs.(params))
end

make_persistent(tensor::TensorDescriptor) = nGraph.make_persistent(tensor)
make_volatile(tensor::TensorDescriptor) = nGraph.make_volatile(tensor)
