@recipe function f(fex::nGraph.FluxExecutable, data::ProfileData, tensor_map::TensorMap)
    # Pre processing
    legend := :none
    xlabel := "Runtime (s)"
    ylabel := "Total Memory Allocated (MiB)"

    size := (1000, 1000)
    left_margin := 20mm
    link := :x

    # Get the execution times for the intermediate ops
    timing_data = read_timing_data(fex.ex.ngraph_function)
    node_times = map(nodes(data)) do node
        if !hasprofile(node) && !ismove(node)
            return 0.0
        end

        index = findonly(x -> x["name"] == name(node), timing_data)
        return timing_data[index]["dur"]
    end |> cumsum |> x -> x ./ 1E6

    node_to_index = Dict(n => i for (i,n) in enumerate(nodes(data)))

    # Keep a rolling tally of y-coordinates
    #subplot := 1
    y_start = 0.0

    # Map tensors to their "y" coordinate. Used for tracking move nodes.
    tensor_to_y = Dict{TensorDescriptor, Float64}()
    for (index, newlist) in enumerate(data.newlist)
        x_start = node_times[index]

        isempty(newlist) && continue

        rectangles = Tuple{Vector{Float64}, Vector{Float64}}[]  # Inconvenient data type ...
        colors = Symbol[]
        for tensor in newlist
            # If this is a parent, make a new bar.
            if isparent(tensor_map, tensor) 
                this_y = y_start
                tensor_to_y[tensor] = this_y
                y_start += sizeof(tensor)

            # Otherwise, figure out the appropriate y-coordinate for this tensor.
            else
                parent = getparent(tensor_map, tensor)
                this_y = tensor_to_y[parent]

                # Sanity check. Make sure sizes are preserved
                @assert sizeof(parent) == sizeof(tensor)
            end

            # Get the start time
            height = sizeof(tensor)  
            x_start = node_times[index]
            _idx = min(length(node_times), node_to_index[_consumer(tensor, data)]+1)
            x_stop = node_times[_idx]

            push!(rectangles, rectangle(x_start, this_y, x_stop - x_start, height))
            push!(colors, nGraph.is_persistent(tensor) ? :red : :blue)
        end

        # Plot the tensor indices
        seriestype := :shape
        linewidth := 0
        linealpha := 0

        for (rectangle, color) in zip(rectangles, colors)
            @series begin
                c := color

                x = first(rectangle)
                y = last(rectangle)

                x, y
            end
        end
    end
end
