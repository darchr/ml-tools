rectangle(x, y, w, h) = (x .+ [0, w, w, 0]), (y .+ [0, 0, h, h])

struct PlotSeries
    # Rectangles representing tensors during their live range as well as colors
    # for each rectangle
    start_index::Int64
    rectangles::Vector{Tuple{Vector{Float64}, Vector{Float64}}}
    rectangle_colors::Vector{Symbol}

    markers::Vector{Tuple{Float64, Float64}}
    marker_colors::Vector{Symbol}
end

# Holder for metadata to pass around during building
struct PlotBuilder
    # The tensor currently being emitted
    tensor::TensorWrapper
    newlist_index::Int
    y_start::Int

    # Timing of sequential nodes
    node_times::Vector{Float64}
    node_to_index::Dict{NodeWrapper, Int64}
end

_color(x) = x == DRAM ? :blue : :red
_color_marker(x) = x == DRAM ? :black : :darkgreen

function emit_series(frame::Frame, pb::PlotBuilder, metadata::Dict{TensorWrapper, Vector{MoveAction}})
    # Unpack
    data = frame.profile_data
    node_times = pb.node_times
    node_to_index = pb.node_to_index
    tensor = pb.tensor

    # Get the y-coordinates out of the way
    y_start = pb.y_start
    height = sizeof(tensor)

    # Initialize rectangle vectors
    rectangles = Tuple{Vector{Float64},Vector{Float64}}[]
    rectangle_colors = Symbol[]

    markers = Tuple{Float64, Float64}[]
    marker_colors = Symbol[]

    # Begin emitting rectangles by stroling through the move actions.
    moves = get(metadata, tensor, MoveAction[])
    start_index = pb.newlist_index
    x_start = isone(pb.newlist_index) ? 0.0 : node_times[pb.newlist_index-1]

    rolling_index = start_index
    if approx_one(get_tensor_in_dram(frame, tensor, nodes(data, rolling_index)))
        incumbent_location = DRAM
    else
        incumbent_location = PMEM
    end
    for action in moves
        # Color up to the first affected consumer
        x_stop = node_times[rolling_index]
        push!(rectangles, rectangle(x_start, y_start, x_stop - x_start, height))
        push!(rectangle_colors, _color(incumbent_location))
        x_start = x_stop

        rolling_index = node_to_index[last(action.consumers)] + 1
        # Emit markers
        push!(markers, (x_stop, y_start + height / 2))
        push!(marker_colors, _color_marker(action.location))

        # Color the conumsers
        if action.replace_incumbent 
            incumbent_location = action.location
        else
            x_stop = node_times[node_to_index[last(action.consumers)]]
            push!(rectangles, rectangle(x_start, y_start, x_stop - x_start, height))
            push!(rectangle_colors, _color(action.location))
            x_start = x_stop
        end
    end

    # Emit the last rectangle to the end of this tensors live range
    lastind = findfirst(x -> in(tensor, x), data.freelist)
    x_stop = isnothing(lastind) ? last(node_times) : node_times[lastind]

    push!(rectangles, rectangle(x_start, y_start, x_stop - x_start, height))
    push!(rectangle_colors, _color(incumbent_location))

    return PlotSeries(
        start_index, 
        rectangles, 
        rectangle_colors,
        markers,
        marker_colors
    ), y_start + height
end


@recipe function f(frame::Frame, metadata)
    # Pre processing
    legend := :none
    xlabel := "Runtime (s)"
    ylabel := "Total Memory Allocated (MiB)"

    data = frame.profile_data

    # Get the execution times for the intermediate ops
    node_times = map(nodes(data)) do node
        config = getconfig(unwrap(node))

        # Nodes we didn't profile have no timing information, so just return a default
        # zero time for those nodes
        return minimum(get(node.timings, config, 0.0))
    end |> cumsum |> x -> x ./ 1E6

    node_to_index = Dict(n => i for (i,n) in enumerate(nodes(data)))

    # Keep a rolling tally of y-coordinates
    y_start = 0.0
    for (index, newlist) in enumerate(data.newlist)
        x_start = node_times[index]

        isempty(newlist) && continue

        plot_series = PlotSeries[]
        for tensor in newlist

            builder = PlotBuilder(tensor, index, y_start, node_times, node_to_index)
            ps, y_start = emit_series(frame, builder, metadata)
            push!(plot_series, ps)
        end

        # Sort the tensors for prettiness
        sort!(plot_series; by = x -> x.start_index)

        # Plot the tensor indices
        seriestype := :shape
        linewidth := 0
        linealpha := 0

        for ps in plot_series
            for (rectangle, color) in zip(ps.rectangles, ps.rectangle_colors)
                @series begin
                    c := color

                    x = first(rectangle)
                    y = last(rectangle)

                    x, y
                end
            end
        end

        seriestype := :scatter
        markerstrokealpha := 0.0

        for ps in plot_series
            isempty(ps.markers) && continue
            @series begin
                x = Float64[]
                y = Float64[]
                colors = Symbol[]
                for (pair, color) in zip(ps.markers, ps.marker_colors)
                    push!(x, first(pair))
                    push!(y, last(pair))
                    push!(colors, color)
                end
                c := colors

                x, y
            end
        end
    end
end

#####
##### Plot the DRAM allocation of a graph
#####

struct AllocationView end
@recipe function f(::AllocationView, fex::nGraph.FluxExecutable)
    profile_data = ProfileData(fex)
    fn = fex.ex.ngraph_function

    tensor_map = Dict{String, nGraph.TensorDescriptor}()
    for op in fn
        for t in nGraph.output_descriptors(op)
            tensor_map[nGraph.get_name(t)] = t
        end
    end

    seriestype := :shape
    legend := :none
    linecolor := :white

    tensor_set = Set{String}()
    starts = Dict{String, Int64}()

    count = 0
    for (index, tensor_names) in enumerate(live_tensors(profile_data))
        filtered_names = filter(!in(profile_data.fixed_tensors), tensor_names)
        for tensor_name in filtered_names
            in(tensor_name, profile_data.fixed_tensors) && continue

            # Find tensors that are no longer live
            for n in tensor_set
                if !in(n, filtered_names)
                    delete!(tensor_set, n)
                    count += 1

                    tensor = tensor_map[n]
                    nGraph.is_persistent(tensor) && continue
                    @series begin
                        x = starts[n]
                        width = index - x


                        y = nGraph.get_pool_offset(tensor) / 1E6
                        height = sizeof(tensor) / 1E6

                        if width > 500
                            @show n
                            @show x
                            @show width
                            @show y
                            @show height
                            println()
                        end

                        if startswith(nGraph.get_name(tensor), "Move")
                            c := :red
                        else
                            c := :black
                        end

                        x, y = rectangle(x, y, width, height)
                        x = Float64.(x)
                        y = Float64.(y)

                        x, y
                    end
                end
            end

            for n in filtered_names
                if !in(n, tensor_set)
                    starts[n] = index
                    push!(tensor_set, n)
                end
            end
        end
    end
end
