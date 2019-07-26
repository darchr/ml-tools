function call(layers, x; layer_type = Conv)
    record_layers = []
    for l in layers
        x = l(x)
        if isa(l, layer_type)
            push!(record_layers, x)
        end
    end
    return x, record_layers...
end

debug_vgg() = [
    # First Layer
    Conv((3,3), 3 => 64, relu; pad = 1),
    Conv((3,3), 64 => 64, relu; pad = 1),
    MaxPool((2,2)),
    # Second Layer
    Conv((3,3), 64 => 128, relu; pad = 1),
    Conv((3,3), 128 => 128, relu; pad = 1),
    MaxPool((2,2)),
    # Third Layer
    Conv((3,3), 128 => 256, relu; pad = 1),
    Conv((3,3), 256 => 256, relu; pad = 1),
    Conv((3,3), 256 => 256, relu; pad = 1),
    Conv((3,3), 256 => 256, relu; pad = 1),
    MaxPool((2,2)),
    # Fourth Layer
    Conv((3,3), 256 => 512, relu; pad = 1),
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
    softmax,
]

function vgg_debug_training(batchsize)
    # Set seed
    Random.seed!(1234)

    x = rand(Float32, 224, 224, 3, batchsize)
    y = zeros(Float32, 1000, batchsize)
    for col in 1:batchsize
        y[rand(1:1000), col] = one(eltype(y))
    end

    X = x
    Y = y

    # Get the forward pass
    layers = debug_vgg()

    # Compute the backward pass.
    f = function(x, y)
        r = call(layers, x)
        return Flux.crossentropy(first(r), y), Base.tail(r)...
    end

    kw = (optimizer = nGraph.SGD(Float32(0.005)),)
    return f, (X,Y), kw
end

