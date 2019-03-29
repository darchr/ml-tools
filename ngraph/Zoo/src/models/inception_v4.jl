# We're going to create a struct that executes a bunch of parallel branches and then
# concatenates the results back together
struct InceptionBlock{T <: Tuple}
    branches::T
end

InceptionBlock(x, y, args...) = InceptionBlock((x, y, args...))

# Flux likes the "@treelike" macro for doing backpropogation.
Flux.@treelike InceptionBlock

function (block::InceptionBlock)(x)
    # Call branches
    results = map(f -> f(x), block.branches)
    return cat(results...; dims = 3)
end

# We're gonna be REALLY mean to type inference. Sorry Julia!
function stem(input)
    println("Stem")

    return Chain(
        # Initial Stem
        Conv((3, 3), 3 => 32, relu; pad = 0, stride = 2),
        Conv((3, 3), 32 => 32, relu; pad = 0),
        Conv((3, 3), 32 => 64, relu; pad = 1),

        # First Split
        InceptionBlock(
            MaxPool((3,3); pad = 0, stride = 2),
            Conv((3,3), 64 => 96, relu; pad = 0, stride = 2),
        ),

        # Second Split
        InceptionBlock(
            Chain(
                Conv((1,1), 160 => 64, relu; pad = 0, stride = 1),
                Conv((3,3), 64 => 96, relu; pad = 0),
            ),
            Chain(
                Conv((1,1), 160 => 64, relu; pad = 0),
                Conv((7,1), 64 => 64, relu; pad = (3,0)),
                Conv((1,7), 64 => 64, relu; pad = (0,3)),
                Conv((3,3), 64 => 96, relu; pad = 0),
            ),
        ),

        # Final Split
        InceptionBlock(
            Conv((3,3), 192 => 192, relu; pad = 0, stride = 2),
            MaxPool((3,3); pad = 0, stride = 2),
        )
    )
end

function inception_a(x)
    println("A Block")
    return InceptionBlock(
        Chain(
            x -> meanpool(x, (3,3); pad = 1, stride = 1),
            Conv((1,1), 384 => 96, relu; pad = 0)
        ),
        Conv((1,1), 384 => 96, relu; pad = 0),
        Chain(
            Conv((1,1), 384 => 64, relu; pad = 0),
            Conv((3,3), 64 => 96, relu; pad = 1)
        ),
        Chain(
            Conv((1,1), 384 => 64, relu; pad = 0),
            Conv((3,3), 64 => 96, relu; pad = 1),
            Conv((3,3), 96 => 96, relu; pad = 1)
        )
    )   
end

function inception_b(x)
    println("B Block")
    S = size(x, 3)
    return InceptionBlock(
        Chain(
            x -> meanpool(x, (3,3); pad = 1, stride = 1),
            Conv((1,1), S => 128)
        ),
        Conv((1,1), S => 384, relu),
        Chain(
            Conv((1,1), S => 192, relu),
            Conv((1,7), 192 => 224, relu; pad = (0, 3)),
            Conv((7,1), 224 => 256, relu; pad = (3, 0)),
        ),
        Chain(
            Conv((1,1), S => 192, relu),
            Conv((1,7), 192 => 192, relu; pad = (0, 3)),
            Conv((7,1), 192 => 224, relu; pad = (3, 0)),
            Conv((1,7), 224 => 224, relu; pad = (0, 3)),
            Conv((7,1), 224 => 256, relu; pad = (3, 0)),
        )
    )
end

function inception_c(x)
    println("C Block")
    S = size(x, 3)
    return InceptionBlock(
        Chain(
            x -> meanpool(x, (3,3); pad = 1, stride = 1),
            Conv((1,1), S => 256, relu)
        ),
        Conv((1,1), S => 256, relu),
        Chain(
            Conv((1, 1), S => 384, relu),
            InceptionBlock(
                Conv((1, 3), 384 => 256, relu; pad = (0, 1)),
                Conv((3, 1), 384 => 256, relu; pad = (1, 0)),
            ),
        ),
        Chain(
            Conv((1,1), S => 384, relu),
            Conv((1,3), 384 => 448, relu; pad = (0, 1)),
            Conv((3,1), 448 => 512, relu; pad = (1, 0)),
            InceptionBlock(
                Conv((1,3), 512 => 256, relu; pad = (0, 1)),
                Conv((3,1), 512 => 256, relu; pad = (1, 0)),
            ),
        )
    )
end

function inception_ra(x, k, l, m, n)
    println("A Reduction")
    S = size(x, 3)
    return InceptionBlock(
        x -> maxpool(x, (3,3); pad = 0, stride = 2),
        Conv((3,3), S => n, relu; pad = 0, stride = 2),
        Chain(
            Conv((1,1), S => k, relu),
            Conv((3,3), k => l, relu; pad = 1),
            Conv((3,3), l => m, relu; pad = 0, stride = 2)
        ),
    )
end

function inception_rb(x)
    println("B Reduction")
    S = size(x, 3)
    return InceptionBlock(
        x -> maxpool(x, (3,3); pad = 0, stride = 2),

        Chain(
            Conv((1,1), S => 192, relu),
            Conv((3,3), 192 => 192, relu; pad = 0, stride = 2)
        ),

        Chain(
            Conv((1,1), S => 256, relu; pad = 0),
            Conv((1,7), 256 => 256, relu; pad = (0, 3)),
            Conv((7,1), 256 => 320, relu; pad = (3, 0)),
            Conv((3,3), 320 => 320, relu; pad = 0, stride = 2)
        ),
    )
end

mutable struct SizeTracker
    layers::Vector{Any}
    array::Any
end

function Base.push!(S::SizeTracker, f, call = true)
    # This is kind of mindbending ...
    #
    # We call the provided function to get another function that we append onto the
    # layers. Then, we call that generated function to get the new array size.
    if call
        push!(S.layers, f(S.array))
    else
        push!(S.layers, f)
    end

    S.array = last(S.layers)(S.array)
end

function inception_v4(x)
    layers = SizeTracker([], x)
    push!(layers, stem)
    for _ in 1:4
        push!(layers, inception_a)
    end
    push!(layers, x -> inception_ra(x, 192, 224, 256, 384))

    for _ in 1:7
        push!(layers, inception_b)
    end
    push!(layers, inception_rb)

    for _ in 1:3
        push!(layers, inception_c)
    end

    kernel_size = size.(Ref(layers.array), (1, 2))
    push!(layers, x -> meanpool(x, kernel_size; pad = 0, stride = 1), false)
    # dropout
    
    push!(layers, x -> reshape(x, :, size(x,4)), false)
    push!(layers, Dense(1536, 1000), false)
    push!(layers, x -> log.(max.(x, Float32(1e-9))), false),
    push!(layers, softmax, false)

    return Chain(layers.layers...)
end

function inception_v4_inference(batchsize)
    x = rand(Float32, 299, 299, 3, batchsize)
    x = (x .- mean(x)) ./ std(x)

    backend = nGraph.Backend()
    X = nGraph.Tensor(backend, x)

    f = nGraph.compile(backend, inception_v4(x), X)
    return f, (X,)
end

function inception_v4_training(batchsize; kw...)
    x = rand(Float32, 299, 299, 3, batchsize)
    x = (x .- mean(x)) ./ std(x)

    y = rand(Float32, 1000, batchsize)
    random_labels!(y) 

    backend = nGraph.Backend()
    X = nGraph.Tensor(backend, x)
    Y = nGraph.Tensor(backend, y)

    forward = inception_v4(x)

    # TODO: Bad loss function for now
    f(x, y) = Flux.crossentropy(forward(x), y)

    g = nGraph.compile(backend, f, X, Y; optimizer = nGraph.SGD(Float32(0.001)), kw...)
    return g, (X, Y)
end

#####
##### Simple Test function
#####

_mnist() = Chain(
        # First convolution, operating upon a 28x28 image
        Conv((3, 3), 1=>16, pad=(1,1), relu),
        MaxPool((2,2)),

        # Second convolution, operating upon a 14x14 image
        Conv((3, 3), 16=>32, pad=(1,1), relu),
        MaxPool((2,2)),

        # Third convolution, operating upon a 7x7 image
        Conv((3, 3), 32=>32, pad=(1,1), relu),
        MaxPool((2,2)),

        # Reshape 3d tensor into a 2d one, at this point it should be (3, 3, 32, N)
        # which is where we get the 288 in the `Dense` layer below:
        x -> reshape(x, :, size(x, 4)),
        Dense(288, 10, relu),

        # Finally, softmax to get nice probabilities
        x -> log.(max.(x, Float32(1e-9))),
        x -> softmax(x)
    )

function mnist(batchsize = 16)
    model = _mnist()

    backend = Backend()
    x = rand(Float32, 28, 28, 1, batchsize)
    X = nGraph.Tensor(backend, x)
    f = nGraph.compile(backend, model, X)

    return f, X
end

# Include an additional modifier to allow modifying the optimizer
function mnist_train(batchsize = 16, modifier = identity)
    model = _mnist()
    backend = nGraph.Backend()

    x = rand(Float32, 28, 28, 1, batchsize)
    x = (x .- mean(x)) ./ std(x)

    y = zeros(Float32, 10, batchsize)
    random_labels!(y)

    f(x, y) = Flux.crossentropy(model(x), y)
    X = nGraph.Tensor(backend, x)
    Y = nGraph.Tensor(backend, y)

    g = nGraph.compile(backend, f, X, Y; optimizer = modifier(nGraph.SGD(Float32(0.001))))
    return g, (X, Y)
end

function makeconv(; filter = (3,3), channels = 256, filters = 256)
    c = Conv(filter, channels => filters)
    backend = Backend()
    X = Tensor(backend, rand(Float32, 17, 17, 256, 16))
    f = compile(backend, c, X)
    return f, X
end
