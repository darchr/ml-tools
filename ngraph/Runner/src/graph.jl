const _etype = NamedTuple{(:name, :index), Tuple{String, Int}}

struct ExtractedGraph
    node_map::Dict{String, nGraph.Node}
    input_map::Dict{String, Vector{_etype}}
    output_map::Dict{String, Vector{Vector{_etype}}}
end

Base.getindex(E::ExtractedGraph, s::String) = E.node_map[s]
getinputs(E::ExtractedGraph, s::String) = E.input_map[s]
getoutputs(E::ExtractedGraph, s::String) = E.output_map[s]
getoutputs(E::ExtractedGraph, s::String, i) = E.output_map[s][i]

output_names(E::ExtractedGraph, s::String, i) = getproperty.(E.output_map[s][i], :name)


ExtractedGraph(fex::nGraph.FluxExecutable) = ExtractedGraph(fex.ex.ngraph_function)
function ExtractedGraph(ngraph_function::nGraph.NFunction)
    # Intermediate files are generated from the function name. We grap that here so we know
    # what to look for later
    function_name = nGraph.name(ngraph_function)

    # Iterate through all of the ops in nGraph
    node_map = Dict{String, nGraph.Node}()

    input_map = Dict{String, Vector{_etype}}()

    # Note: due to the way nGraph is constructed, each output from a node can have multiple
    # users. Thus, to construct the output node map, we first construct the input node map
    # and then traverse it.

    for op in ngraph_function
        op_name = nGraph.name(op)
        
        # Here, we get a tuple with a Node and an index.
        #
        # The node input node for this input of the graph and the index is the output
        # index that this node references.
        input_tuples = nGraph.get_inputs(op)

        # Do some doctoring to get the convert the returned tuple to a named tuple for
        # slightly nices processing
        inputs = map(x -> (name = nGraph.name(first(x)), index = last(x)), input_tuples)

        # Save a bunch of metadata
        node_map[op_name] = op
        input_map[op_name] = inputs
    end

    # Make an output map for easy bi-directional graph traversals.
    output_map = Dict(
        nGraph.name(op) => [Vector{_etype}() for _ in 1:nGraph.get_output_size(op)] 
        for op in ngraph_function
    )

    for (op_name, inputs) in input_map
        for (index, input) in enumerate(inputs) 
            input_name = input.name 
            input_output_index = input.index

            push!(output_map[input_name][input_output_index], (name = op_name, index = index))
        end
    end

    return ExtractedGraph(node_map, input_map, output_map)
end
