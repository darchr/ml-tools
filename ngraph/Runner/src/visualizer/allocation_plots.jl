rectangle(x, y, w, h) = (x .+ [0, w, w, 0]), (y .+ [0, 0, h, h])

@recipe function f(fex::nGraph.FluxExecutable, frame::Frame, tensor_map::TensorMap)
    # Pre processing
    legend := :none
    xlabel := "Runtime (s)"
    ylabel := "Total Memory Allocated (MiB)"
    layout := @layout [ allocations{0.4h}
                       dram_read{0.1h}
                       dram_write{0.1h}
                       pmem_read{0.1h}
                       pmem_write{0.1h}
                       dram_to_pmem{0.1h}
                       pmem_to_dram{0.1h} ]

    size := (1000, 1000)
    left_margin := 20mm
    link := :x

    data = frame.profile_data

    # Get the execution times for the intermediate ops
    timing_data = read_timing_data(fex.ex.ngraph_function)
    node_times = map(nodes(data)) do node
        hasprofile(node) || return 0.0

        index = findonly(x -> x["name"] == name(node), timing_data)
        return timing_data[index]["dur"]
    end |> cumsum |> x -> x ./ 1E6

    node_to_index = Dict(n => i for (i,n) in enumerate(nodes(data)))

    # Keep a rolling tally of y-coordinates
    subplot := 1
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
            x_stop = node_times[node_to_index[_consumer(tensor, data)]]

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

    #####
    ##### Create a secondary plot for displaying bandwidth
    #####

    # Gather all data into a NamedTuple
    x = Float64[0.0]
    syms = (:dram_read, :dram_write, :pmem_read, :pmem_write, :dram_to_pmem, :pmem_to_dram)
    vals = NamedTuple{syms}(ntuple(x -> Float64[], length(syms)))

    for i in eachindex(nodes(data))
        node = nodes(data, i)

        # The `x` value is just the time of this node.
        push!(x, node_times[i])

        # Append zero to each `y` value.
        for sym in syms
            arr = vals[sym]
            push!(arr, zero(eltype(arr)))
        end

        # Treat moves and normal ops separately
        if !ismove(node)
            # Tally up inputs and outputs
            for input in inputs(node)
                if nGraph.is_persistent(input)
                    vals[:pmem_read][end] += sizeof(input)
                else
                    vals[:dram_read][end] += sizeof(input)
                end
            end
            for output in outputs(node)
                if nGraph.is_persistent(output)
                    vals[:pmem_write][end] += sizeof(output)
                else
                    vals[:dram_write][end] += sizeof(output)
                end
            end
        else
            input = first(inputs(node))
            @show sizeof(input)
            if nGraph.is_persistent(input)
                vals[:pmem_to_dram][end] += sizeof(input)
            else
                vals[:dram_to_pmem][end] += sizeof(input)
            end
        end
    end

    seriestype := :bar
    linewidth := 1
    linealpha := 1.0

    # Bar_edges is not available for the GR backend.
    # instead, compute the center of the bars
    bar_centers = (x[1:end-1] .+ x[2:end]) ./ 2
    widths = diff(x)

    # Generate the plot
    subplot_index = 2

    for sym in syms
        @series begin
            subplot := subplot_index
            title := titlecase(string(sym))
            bar_width := widths
            y = vals[sym] ./ 1E6

            bar_centers, y
        end
        subplot_index += 1
    end
end
