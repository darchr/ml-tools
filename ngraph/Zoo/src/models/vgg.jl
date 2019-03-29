vgg19() = Chain(
        # First Layer
        Conv((3,3), 3 => 64, relu; pad = 1),
        Conv((3,3), 64 => 128, relu; pad = 1),
        MaxPool((2,2)),
        # Second Layer 
        Conv((3,3), 128 => 128, relu; pad = 1),
        Conv((3,3), 128 => 256, relu; pad = 1),
        MaxPool((2,2)),
        # Third Layer
        Conv((3,3), 256 => 256, relu; pad = 1),
        Conv((3,3), 256 => 256, relu; pad = 1),
        Conv((3,3), 256 => 256, relu; pad = 1),
        Conv((3,3), 256 => 512, relu; pad = 1),
        MaxPool((2,2)),
        # Fourth Layer
        Conv((3,3), 512 => 512, relu; pad = 1),
        Conv((3,3), 512 => 512, relu; pad = 1),
        Conv((3,3), 512 => 512, relu; pad = 1),
        Conv((3,3), 512 => 512, relu; pad = 1),
        MaxPool((2,2)),
        # Fifth Layer
        Conv((3,3), 512 => 512, relu; pad = 1),
        Conv((3,3), 512 => 512, relu; pad = 1),
        Conv((3,3), 512 => 512, relu; pad = 1),
        Conv((3,3), 512 => 512, relu; pad = 1),
        MaxPool((2,2)),
        # Fully Connected Layers
        x -> reshape(x, :, size(x, 4)), 
        Dense(25088, 4096, relu),
        Dense(4096, 4096, relu),
        Dense(4096, 1000),
        # Add a small positive value to avoid NaNs
        x -> log.(max.(x, Float32(1e-9))),
        softmax
    )

function vgg19_inference(batchsize)
    x = rand(Float32, 224, 224, 3, batchsize)

    x = (x .- mean(x)) ./ std(x)

    backend = nGraph.Backend()
    X = nGraph.Tensor(backend, x)

    forward = vgg19()

    g = nGraph.compile(backend, forward, X)
    return g, (X,)
end

function vgg19_training(batchsize; kw...)
    x = rand(Float32, 224, 224, 3, batchsize)
    y = zeros(Float32, 1000, batchsize)
    for col in 1:batchsize
        y[rand(1:1000), col] = one(eltype(y))
    end

    backend = nGraph.Backend()
    X = nGraph.Tensor(backend, x)
    Y = nGraph.Tensor(backend, y)

    # Get the forward pass
    forward = vgg19()
    
    # Compute the backward pass.
    f(x, y) = Flux.crossentropy(forward(x), y)

    g = nGraph.compile(backend, f, X, Y; optimizer = nGraph.SGD(Float32(0.05)), kw...)
    return g, (X, Y)
end

function random_labels!(y)
    y .= zero(eltype(y))
    for j in 1:size(y, 2)
        y[rand(1:size(y, 1)), j] = one(eltype(y))
    end
end
