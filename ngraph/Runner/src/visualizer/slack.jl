# Show timing slack of overlapped functions
function slack_plot(fex::nGraph.FluxExecutable, frame)
    # Do the mandatory unpacking
    ex = fex.ex
    f = ex.ngraph_function
    data = frame.profile_data
    model = frame.model
    node_times = model[:node_times]

    rolling_timer = 0.0 
    #performance = nGraph.get_performance(ex)

    runtimes = []
    movetimes = []
    for node in NodeDescriptor.(f)
        node_name = nGraph.name(node)
        haskey(node_times, node_name) || continue

        async_move_time = 0.0
        # Plot the expected and async move times.
        _async = get(model[:tensor_async], node_name, nothing)
        if !isnothing(_async) && !iszero(JuMP.value(_async))
            # Get the expected asynchronous move times from the 
            async_move_time = JuMP.value(_async)

            push!(movetimes, rectangle(rolling_timer, 5, async_move_time, 2))
        end

        # If this is a move, add the measured time 
        runtime = JuMP.value(node_times[node_name])
        push!(runtimes, rectangle(rolling_timer, 0, runtime, 2))

        rolling_timer += max(runtime, async_move_time)
    end

    # Generate a plot
    plt = plot(;legend = :none)
    kw = (
        linewidth = 0,
        linealpha = 0,
        seriestype = :shape,
    )

    for r in runtimes
        plot!(plt, first(r), last(r); c = "blue", kw...)
    end

    for r in movetimes
        plot!(plt, first(r), last(r); c = "red", kw...)
    end

    png(plt, "plot.png")
    return nothing
    #return plt
end
