module Runner

using nGraph, Flux, JSON

#####
##### PMEM initialization
#####

function setup_pmem(file = "/mnt/public/file.pmem", size = 2^32)
    ispath(file) && rm(file)

    manager = nGraph.Lib.getinstance()
    @show manager
    nGraph.Lib.create_pool(manager, file, convert(UInt, size))
    return nothing
end

#####
##### Example Network Building
#####

function _network(x)
    # Construct a conv followed by a max pool
    chain = Chain(
        Conv((3, 3), size(x, 3) => 128, relu; pad = (1, 1)),
        x -> maxpool(x, (3, 3); stride = (1, 1)),
        x -> reshape(x, :,  size(x, 4))
    )

    # Perform this operation
    y = chain(x) 

    # Get the size of `x` and use that to construct a `Dense` layer
    return softmax(Dense(size(y, 1), 10, relu)(y))
end

function simple_network()
    # Instantiate the nGraph backend object
    backend = nGraph.Backend()

    batchsize = 8
    nchannels = 16

    # Create a nGraph tensor
    X = nGraph.Tensor(backend, rand(Float32, 20, 20, nchannels, batchsize))

    f = nGraph.compile(backend, _network, X)

    # Return the arguments as a tuple so in the future, we can return multiple compiled 
    # function arguments and still have downstream code work.
    return f, (X,)
end


# Simple test for seeing if the compilation chain for Persistent Memory works.
function persistent_memory_test()
    # Setup PMEM
    setup_pmem() 

    # Create the function
    f, args = simple_network() 

    # This involves digging into the internals of nGraph a little bit - we tunnel through
    # the compiled function to get the underlying nGraph function
    ngraph_function = f.ex.ngraph_function 

    # Iterate through the ops in the function. If we will try to change the output of the
    # max pool operation
    for i in 1:length(ngraph_function)
        op = ngraph_function[i]
        @show nGraph.name(op)
        if nGraph.description(op) == "MaxPool"
            println("    Making Persistent")
            # Get the output tensor - make it as persistent.
            tensor_ptr = nGraph.Lib.get_output_tensor_ptr(op.ptr)  

            # Mark this tensor as belonging in persistent memory
            nGraph.Lib.make_persistent(tensor_ptr)
        end
    end

    # Recompile the function
    backend = nGraph.Backend()
    g = nGraph.recompile(backend, f)

    return g, args
end


_skip(op) = in(nGraph.description(op), ("Parameter", "Constant", "Result"))
keep(op) = !_skip(op)

@enum TensorLocation::UInt8 DRAM PMEM

struct WorklistEntry
    name::String
    inputs::Vector{TensorLocation}
    outputs::Vector{TensorLocation}
end

# Steps
#
# - Get all of the op names
# - Build datastructures:
#
#       * Node Names -> Node
#       * Node Names -> Inputs and Outputs
#       * Data structure mappint Node Name + I/O PMEM state to times
#
#   This last data structure we will use for setting the states of internal variables as 
#   well as selecting the next state to explore.
#
# NOTE: We should skip "constants" as we don't yet have the technology to map these into
# PMEM.
function memory_profile(exe::nGraph.FluxExecutable, args)
    # Unpack the function
    ngraph_function = exe.ex.ngraph_function

    # Intermediate files are generated from the function name. We grap that here so we know
    # what to look for later
    function_name = nGraph.name(ngraph_function)

    # Iterate through all of the ops in nGraph
    node_map = Dict{String, nGraph.Node}()

    etype = NamedTuple{(:name, :index), Tuple{String, Int}}
    input_map = Dict{String, Vector{etype}}()

    # Note: due to the way nGraph is constructed, each output from a node can have multiple
    # users. Thus, to construct the output node map, we first construct the input node map
    # and then traverse it.

    for i in 1:length(ngraph_function)
        op = ngraph_function[i]

        # We want to ignore some ops.
        if !_skip(op)
            op_name = nGraph.name(op)
            
            # Here, we get a tuple with a Node and an index.
            #
            # The node input node for this input of the graph and the index is the output
            # index that this node references.
            input_tuples = nGraph.get_inputs(op)

            # Do some doctoring to get the convert the returned tuple to a named tuple for
            # slightly nices processing
            filter!(x -> keep(first(x)), input_tuples)
            inputs = map(x -> (name = nGraph.name(first(x)), index = last(x)), input_tuples)

            # Save a bunch of metadata
            node_map[op_name] = op
            input_map[op_name] = inputs

            println("Op: $op_name")
            for i in 1:length(inputs)
                println("    Input $i: $(inputs[i].name) : $(inputs[i].index)")
            end
            println()
        end
    end

    # Construct the output_map from the inputs
    # Initialize an empty dict with 
    #
    # - Keys: Node Names
    # - Values: Vector with a length equal to the number of outputs for the node
    #   - Elements of the vector are all the user nodes of that output
    #     - Encoded as a NamedTuple with `name => node_name`, `index => input_index`
    output_map = Dict(name => [Vector{etype}() for _ in 1:nGraph.get_output_size(node_map[name])] for name in keys(input_map))
    for (node_name, inputs) in input_map
        for input_index in eachindex(inputs)
            # Register this node at the outputs
            nt = (name = node_name, index = input_index) 

            user_node_name = inputs[input_index].name
            user_node_input_index = inputs[input_index].index
            push!(output_map[user_node_name][user_node_input_index], nt)
        end
    end

    # Now that we have that out of the way, we generate a dictionary mapping node names to
    # all the combinations of inputs and outputs in DRAM/PMEM
    worklist =   
end

end # module
