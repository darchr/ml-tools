# Inspection routines for the post optimized ILP model
function list_overlaps(frame::Frame)
    model = frame.model
    node_times = model[:node_times]
    for node in nodes(frame.profile_data)
        node_name = nGraph.name(node)
        haskey(node_times, node_name) || continue
        _async = get(model[:tensor_async], node_name, nothing)
        if !isnothing(_async) && !iszero(JuMP.value(_async))
            # Get the values of the asynchronous move times
            async_move_time = JuMP.value(_async)
            node_execution_time = JuMP.value(node_times[node_name])

            @info """
            Overlap times for $node_name
            Node Execution Time: $node_execution_time
            Async Move Time : $async_move_time
            """
        end
    end
end
