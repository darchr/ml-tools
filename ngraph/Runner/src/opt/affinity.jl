# Some passes for assigning node affinity.
#
# This applies heuristics to nodes like `Broadcast` and `Result` to schedule them in more
# sensible locations
function apply_affinity_heuristic!(f::nGraph.NFunction; 
        output_affinities = ("Broadcast",),
        input_affinities = ("Result",),
    )

    for node_unwrapped in f
        node = NodeDescriptor(node_unwrapped)
        node_name = nGraph.name(node)

        # Apply appropriate affinties
        if any(x -> startswith(node_name, x), input_affinities)
            nGraph.set_input_affinity(node)
            for input in nGraph.get_inputs(node)
                nGraph.add_associate(node, nGraph.name(input))
            end
        elseif any(x -> startswith(node_name, x), output_affinities)
            nGraph.set_output_affinity(node)
            for output in nGraph.get_outputs(node)
                nGraph.add_associate(node, nGraph.name(output))
            end
        end
    end
end
