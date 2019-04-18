function find_vertex(g, f)
    iter = filter_vertices(g, f) |> collect
    # Makesure we only have one match
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
    # Get the producer of this tensor
    #
    # TODO: Need to think very carefully how I treat "getoutputelement" nodes with all of
    # this
    #
    # Currently, the MOVE op will throw an error if the input node has more than out output
    move_node = nGraph.move(producer, index)
    for (consumer, input) in zip(consumers, consumer_inputs)
        nGraph.splice(producer, index, consumer, input, move_node)
    end
    return move_node
end
