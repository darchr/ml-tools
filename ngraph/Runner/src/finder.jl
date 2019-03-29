# NOTE: This is not working - at some point the nodes diverge and I have no idea
# why. It may be that some commutative ops are messing things up, or that the results
# of compilation are not in fact deterministic.
#
# BFS routine for uniquely identifying nodes in a graph across reruns and 
# recompilations.
#
# The general idea is to use a BFS from the input parameters, using the idea that
#
# - The parameters should be ordered
# - The outputs of each node are ordered by index.
strict_order(f::nGraph.FluxExecutable) = strict_order(f.ex.ngraph_function)
function strict_order(f::nGraph.NFunction)
    ordered_nodes = nGraph.Node[]
    results = sort(collect(nGraph.get_results(f)); by = nGraph.name)

    # Keep a list of seen node names to avoid repitition.
    seen_nodes = Set{String}()
    worklist = nGraph.Node[]

    for node in results
        name = nGraph.name(node)
        push!(seen_nodes, name)

        push!(ordered_nodes, node)
        push!(worklist, node)
    end

    # We can only look through the inputs because outputs can have multiple users, and 
    # ngraph uses a std::set to store those, which is an unordered container.
    while !isempty(worklist)
        current_node = popfirst!(worklist)

        # Sort the inputs by description then location to try to get slightly better
        # reproducibility.
        sorted_inputs = sort(nGraph.get_inputs(current_node),
            # Use a stable sorting algorithm
            alg = MergeSort,
            by = nGraph.description
        )

        for input in sorted_inputs
            name = nGraph.name(input)

            if !in(name, seen_nodes)
                push!(seen_nodes, name)
                push!(ordered_nodes, input)
                push!(worklist, input)
            end
        end
    end

    return ordered_nodes
end
