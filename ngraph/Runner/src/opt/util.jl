function find_vertex(g, f)
    iter = filter_vertices(g, f) |> collect
    # Make sure we only have one match
    @assert length(iter) == 1
    return first(iter)
end

function find_edge(g, f)
    iter = filter_edges(g, f) |> collect
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
function insert_move_node!(producer, index, consumers, consumer_inputs)
    move_node = nGraph.move(producer, index)
    for (consumer, input) in zip(consumers, consumer_inputs)
        nGraph.splice(producer, index, consumer, input, move_node)
    end
    
    # Do some verification to make sure the move node was spliced in correctly.
    tensor_name = nGraph.get_name(nGraph.output_descriptor(move_node, 1))
    for (consumer, input) in zip(consumers, consumer_inputs)
        input_name = nGraph.get_name(nGraph.input_descriptor(consumer, input))
        @assert tensor_name == input_name
    end

    return move_node
end
