# A dumping ground for random functions

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

dict_push!(d, k, v) = haskey(d, k) ? push!(d[k], v) : (d[k] = [v])

# For plotting purposes
rectangle(x, y, w, h) = (x .+ [0, w, w, 0]), (y .+ [0, 0, h, h])

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
function insert_move_node!(
        producer::NodeDescriptor, 
        index, 
        consumers::Vector{NodeDescriptor}, 
        consumer_inputs
    )

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
        concurrent,
    )

    move_node = nGraph.moveasync(nGraph.Node(producer), index, nGraph.Node(concurrent))
    for (consumer, input) in zip(consumers, consumer_inputs)
        nGraph.splice(nGraph.Node(producer), index, nGraph.Node(consumer), input, move_node)
    end

    return NodeDescriptor(move_node)
end

#####
##### Methods for dealing with PMEM to DRAM ratios
#####

footprint(datum::Dict) = convert(Int, datum[:pmem_alloc_size] + datum[:dram_alloc_size])

function getratio(datum::Dict)
    pmem = convert(Int, datum[:pmem_alloc_size])
    dram = convert(Int, datum[:dram_alloc_size])
    return pmem // dram
end

getratio(fex::nGraph.FluxExecutable) = getratio(fex.ex.ngraph_function)
function getratio(f::nGraph.NFunction)
    pmem = convert(Int, nGraph.get_pmem_pool_size(f))
    dram = convert(Int, nGraph.get_temporary_pool_size(f))
    return pmem // dram
end

ratio_string(x::Rational) = "$(x.num):$(x.den)"

compare_ratio(a, b) = iszero(b.den) ? inv(a) : a - b

