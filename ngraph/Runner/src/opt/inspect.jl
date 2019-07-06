# Inspection routines for the post optimized ILP model
function list_overlaps(frame::Frame)
    model = frame.model
    for (node_name, node_times) in model[:node_times]
        _async = get(model[:tensor_async], node_name, nothing)
        if !isnothing(_async)
            # Get the values of the asynchronous move times
            async_move_time = JuMP.value(_async)
            node_execution_time = JuMP.value(node_times)

            @info """
            Overlap times for $node_name
            Node Execution Time: $node_execution_time
            Async Move Time : $async_move_time
            """
        end
    end
end
