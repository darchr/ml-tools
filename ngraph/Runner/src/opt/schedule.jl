# An exploration of scheduling
function ilp_schedule(data::ProfileData)
    num_nodes = length(nodes(data))
    
    # Create a model 
    model = Model(with_optimizer(Gurobi.Optimizer; TimeLimit = 600, MIPGap = 0.01)) 

    # Find the number of predecessors and successors for each node
    predecessors = Dict{NodeDescriptor, Set{NodeDescriptor}}()
    for node in nodes(data)
        n = Set{NodeDescriptor}()
        for input in unique(nGraph.get_inputs(node))
            union!(n, predecessors[input], Set{NodeDescriptor}((input,)))
        end
        predecessors[node] = n
    end

    successors = Dict{NodeDescriptor, Set{NodeDescriptor}}()
    for node in reverse(nodes(data))
        n = Set{NodeDescriptor}()
        seen = Set{NodeDescriptor}()
        for output in nGraph.get_outputs(node)
            union!(n, successors[output], Set{NodeDescriptor}((output,)))
        end
        successors[node] = n
    end

    assign_range = Dict{NodeDescriptor, UnitRange{Int64}}()
    for (name, preds) in predecessors
        succs = successors[name]

        start = length(preds)
        stop = length(succs)
        @show name
        @show start
        @show stop
        println()
        assign_range[name] = start:(num_nodes - stop)
    end

    @variable(model, schedule[node = nodes(data), i = assign_range[node]], Bin)

    # Make sure we only schedule a single node at a time.
    @constraint(model, [node = nodes(data)], sum(schedule[node, i] for i in assign_range[node]) == 1)
    @constraint(model, [i = 1:num_nodes], sum(schedule[node, i] for node in nodes(data) if in(i, assign_range[node])) == 1)

    # Add data dependency constraints 
    for node in nodes(data) 
        seen = Set{NodeDescriptor}()
        for output in nGraph.get_outputs(node)
            output_wrapped = NodeDescriptor(output)
            in(output_wrapped, seen) && continue
            # A node must be scheduled before each of its outputs.
            @constraint(model, 
                sum(i * schedule[node, i] for i in assign_range[node])
                <= sum(j * schedule[output_wrapped, j] for j in assign_range[output_wrapped]) - 1)
            push!(seen, output_wrapped)
        end
    end

    return model, assign_range
end
