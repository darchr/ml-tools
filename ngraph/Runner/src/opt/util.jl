function find_vertex(g, f)
    #iter = filter_vertices(g, f) |> collect
    iter = filter(v -> f(g,v), collect(vertices(g)))
    # Make sure we only have one match
    @assert length(iter) == 1
    return first(iter)
end

function find_edge(g, f)
    #iter = filter_edges(g, f) |> collect
    iter = filter(e -> f(g,e), collect(edges(g)))

    # Make sure we only have one match
    @assert length(iter) == 1
    return first(iter)
end

approx_one(x) = isapprox(x, one(x); atol = 1e-3)

"""
    insert_move_node!(producer, index, consumers) -> nGraph.Node

Insert an nGraph `move` node between `producer` and all `consumers`. Return the newly 
created node.
"""
function insert_move_node!(producer::NodeWrapper, index, consumers::Vector{NodeWrapper}, consumer_inputs)
    move_node = nGraph.move(unwrap(producer), index)
    for (consumer, input) in zip(consumers, consumer_inputs)
        nGraph.splice(unwrap(producer), index, unwrap(consumer), input, move_node)
    end
    
    return NodeWrapper(move_node)
end
