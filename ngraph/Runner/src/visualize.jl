rectangle(x, y, w, h) = (x .+ [0, w, w, 0]), (y .+ [0, 0, h, h])

@recipe function f(frame::Frame)
    # Pre processing
    legend := :none
    xlabel := "Runtime (s)"
    ylabel := "Total Memory Allocated (MiB)"

    data = frame.profile_data

    # Get the execution times for the intermediate ops
    node_times = map(nodes(data)) do node
        config = getconfig(frame, node)

        # Nodes we didn't profile have no timing information, so just return a default
        # zero time for those nodes
        return minimum(get(node.timings, config, 0.0))
    end |> cumsum |> x -> x ./ 1E6

    y_coordinate = 0.0
    for (index, newlist) in enumerate(data.newlist)
        x_start = node_times[index]

        isempty(newlist) && continue

        tensor_indices = []
        for tensor in newlist
            # Find the index where the tensor is freed.
            j = findfirst(x -> in(tensor, x), data.freelist)
            if j === nothing
                x_stop = last(node_times)
            else
                x_stop = node_times[j]
            end

            # Get the tensor assignment from the solved model.
            found = false
            bytes = sizeof(tensor)
            for location in locations(data, tensor)
                if approx_one(value(frame.model[:var_tensors][tensor, location]))
                    push!(tensor_indices, (x_start, x_stop, location, bytes))
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

        for (x_start, x_stop, location, bytes) in tensor_indices
            @series begin
                # Determine the color of the line
                if location == PMEM
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
                    elseif meta.location == LOC_PKEEP
                        color = :black
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

#####
##### Plot the DRAM allocation of a graph
#####

struct AllocationView end
@recipe function f(::AllocationView, fn::nGraph.NFunction)
    profile_data = ProfileData(fn)

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
