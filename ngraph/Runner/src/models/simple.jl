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
