rectangle(x, y, w, h) = (x .+ [0, w, w, 0]), (y .+ [0, 0, h, h])

@recipe function f(S::SimpleModel, profile_data::ProfileData, model)
    # Pre processing
    legend := :none
    xlabel := "Runtime (s)"
    ylabel := "Total Memory Allocated (MiB)"

    # Get the execution times for the intermediate ops
    node_times = map(profile_data.nodes) do node
        config = getconfig(S, model, profile_data, node.name)

        # Nodes we didn't profile have no timing information, so just return a default
        # zero time for those nodes
        return minimum(get(node.timings, config, 0.0))
    end |> cumsum |> x -> x ./ 1E6

    y_coordinate = 0.0
    for (index, newlist) in enumerate(profile_data.newlist)
        x_start = node_times[index]

        isempty(newlist) && continue

        tensor_indices = []
        for tensor in newlist
            # Find the index where the tensor is freed.
            j = findfirst(x -> in(tensor, x), profile_data.freelist)
            if j === nothing
                x_stop = last(node_times)
            else
                x_stop = node_times[j]
            end

            # Get the tensor assignment from the solved model.
            found = false
            bytes = profile_data.tensors[tensor].bytes
            for location in profile_data.tensors[tensor].locations
                if value(model[:tensors][tensor, location]) == 1
                    isfixed = in(tensor, profile_data.fixed_tensors)
                    push!(tensor_indices, (x_start, x_stop, location, bytes, isfixed))
                    found = true
                    break
                end
            end
            # Sanity check with a terrible error message
            found || error()
        end

        # Sort the tensors for prettiness
        sort!(tensor_indices)

        # Plot the tensor indices
        seriestype := :shape

        for (x_start, x_stop, location, bytes, isfixed) in tensor_indices
            @series begin
                # Determine the color of the line
                if isfixed
                    color = :green
                elseif location == PMEM
                    color = :red
                else
                    color = :blue
                end
                linecolor := color
                c := color

                height = bytes / 1E6
                width = x_stop - x_start

                x, y = rectangle(x_start, y_coordinate, width, height)

                y_coordinate += height

                x, y
            end
        end
    end
end

#####
##### Plot Synchronous Model
#####

@recipe function f(S::Synchronous, profile_data::ProfileData, model)
    # Setup plot defaults
    legend := :none

    # Perform preprocessing
    schedule = get_schedule(S, profile_data, model)
    y_coordinate = 0.0

    for (index, newlist) in enumerate(profile_data.newlist)
        x_start = index
        isempty(newlist) && continue

        tensor_data = []
        for tensor_name in newlist
            # Find the index where the tensor is freed.
            x_stop = findfirst(x -> in(tensor_name, x), profile_data.freelist)

            # If not found - default to end of the function
            if x_stop === nothing
                x_stop = length(profile_data.freelist)
            end

            # Get the tensor assignment from the solved model.
            bytes = profile_data.tensors[tensor_name].bytes
            isfixed = in(tensor_name, profile_data.fixed_tensors)

            # Create a named tuple with everything we need for the plotting
            nt = (
                x_start = x_start,
                x_stop = x_stop,
                bytes = bytes,
                tensor_name = tensor_name,
                isfixed = isfixed,
                meta = schedule[tensor_name]
            )

            push!(tensor_data, nt)
        end

        # Sort the tensors for prettiness
        sort!(tensor_data; by = x -> (x.x_start, x.x_stop, x.bytes))

        # Plot the tensor indices
        seriestype := :shape

        for nt in tensor_data
            height = nt.bytes / 1E3

            for meta in nt.meta
                in(meta.location, (LOC_SOURCE, LOC_SINK)) && continue
                @series begin
                    if nt.isfixed
                        color = :green
                    elseif meta.location == LOC_DRAM
                        color = :blue
                    elseif meta.location == LOC_PMEM
                        color = :red
                    elseif meta.location == LOC_PREAD
                        color = :cyan
                    end

                    # Create a box around the op
                    x = meta.op
                    width = 2

                    width = 2
                    x, y = rectangle(meta.op, y_coordinate, width, height)

                    # Set properties
                    linecolor := color
                    c := color
                    x, y
                end
            end

            y_coordinate += height
        end
    end
end
