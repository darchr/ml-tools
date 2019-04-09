@recipe function f(profile_data::ProfileData, model)
    legend := :none

    x_coordinate = 1
    for (index, newlist) in enumerate(profile_data.newlist)
        y_start = index

        tensor_indices = []
        for tensor in newlist
            # Find the index where the tensor is freed. 
            y_stop = findfirst(x -> in(tensor, x), profile_data.freelist) 
            if y_stop === nothing
                y_stop = length(profile_data.freelist)
            end
        
            # Get the tensor assignment from the solved model.
            found = false
            bytes = profile_data.tensors[tensor].bytes
            for location in profile_data.tensors[tensor].locations
                if value(model[:tensors][tensor, location]) == 1
                    isfixed = in(tensor, profile_data.fixed_tensors)
                    push!(tensor_indices, (y_start, y_stop, location, bytes, isfixed))
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
        seriestype := :line 

        for (y_start, y_stop, location, bytes, isfixed) in tensor_indices 
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

                x = [x_coordinate, x_coordinate]                
                y = [y_start, y_stop]

                x_coordinate += 1

                y, x
            end
        end
    end
end
