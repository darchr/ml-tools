module Runner

using nGraph, Flux

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
    # Create the function
    f, args = simple_network() 

    # This involves digging into the internals of nGraph a little bit - we tunnel through
    # the compiled function to get the underlying nGraph function
    ngraph_function = f.ex.ngraph_function 

    # Iterate through the ops in the function. If we will try to change the output of the
    # max pool operation
    for i in 1:length(ngraph_function)
        op = ngraph_function[i]
        @show nGraph.description(op)
        if nGraph.description(op) == "MaxPool"
            # Get the output tensor - make it as persistent.
            tensor_ptr = nGraph.Lib.get_output_tensor_ptr(op.ptr)  

            # Mark this tensor as belonging in persistent memory
            nGraph.Lib.make_persistent(tensor_ptr)
        end
    end

    # Recompile the function
    backend = nGraph.Backend()
    g = nGraph.recompile(backend, f)
end

end # module
