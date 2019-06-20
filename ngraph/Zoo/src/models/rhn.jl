# This implementation is largely based on the Tensorflow implementation from the authors
# of the paper:
#
# https://github.com/jzilly/RecurrentHighwayNetworks/blob/master/rhn.py
#
# Various details such as initialization are ignored since that is orthogonal to the actual
# performance of the network.

struct RHNCell
    tanh_layers::Vector
    sigmoid_layers::Vector
end

Flux.@treelike RHNCell

function RHNCell(input_size, hidden_size, depth)
    tanh_layers = []
    sigmoid_layers = []

    for i in 1:depth
        if i == 1
            push!(tanh_layers, Dense(input_size + hidden_size, hidden_size, tanh))
            push!(sigmoid_layers, Dense(input_size + hidden_size, hidden_size, sigmoid))
        else
            push!(tanh_layers, Dense(hidden_size, hidden_size, tanh))
            push!(sigmoid_layers, Dense(hidden_size, hidden_size, sigmoid))
        end
    end
    println("Created RHNCell")

    return RHNCell(tanh_layers, sigmoid_layers)
end

function (R::RHNCell)(input, current_state)#, noise_i, noise_h)
    isfirst = true
    for (_tanh, _sigmoid) in zip(R.tanh_layers, R.sigmoid_layers)
        #noisy_state = current_state .* noise_h
        if isfirst
            #noise_i_broadcast = broadcast(noise_i, size(input); axes = 2)
            _cat = cat(input, current_state; dims = 1)
            h = _tanh(_cat)
            t = _sigmoid(_cat)

            isfirst = false
        else
            h = _tanh(current_state)
            t = _sigmoid(current_state)
        end

        # Update state
        current_state = (h .- current_state) .* t .+ current_state
    end

    return current_state
end

struct RHNModel{T,U}
    embedding_table::T
    rhn_cells::U
    num_steps::Int
end

Flux.@treelike RHNModel

# Like the tensorflow model, but parameters may be passed by NamedTuple as well using
# keyword spatting
function rhn_model(;
        num_layers = 1,
        depth = 4,      # Recurrence depth
        num_steps = 35,
        hidden_size = 1000,
        batch_size = 20,
        vocab_size = 10000,
    )

    if vocab_size < hidden_size
        in_size = vocab_size
    else
        in_size = hidden_size
    end

    # Create the embedding table.
    #
    # Just leave this as a normal array so we don't try to autodiff through it.
    # nGraph does not support differentiation of embedding tables
    embedding_table = rand(Float32, in_size, vocab_size)

    # Create RHN cells
    rhn_cells = [RHNCell(hidden_size, in_size, depth) for _ in 1:num_layers]

    return RHNModel(embedding_table, rhn_cells, num_steps)
end

function (R::RHNModel)(input, targets, states)#, noise_x, noise_i, noise_h, noise_o)
    # Do the embedding lookup
    embedding = nGraph.constant(R.embedding_table) 
    #inputs = nGraph.embedding(input, embedding)
    inputs = input
    @show size(inputs)

    # Broadcast over the first dimension
    #noise_broadcast = broadcast(noise_x, size(inputs); axes = 1)
    inputs = inputs# .* noise_broadcast

    # Split inputs into an array for each timestep
    #
    # Drop the last dimensions
    inputs = map(
        x -> reshape(x, (size(x,1), size(x,2))), 
        [inputs[:, :, timestep] for timestep in 1:R.num_steps]
    )

    states = map(
        x -> reshape(x, (size(x,1), size(x,2))), 
        [states[:, :, layer] for layer in 1:length(R.rhn_cells)]
    )

    # Go through the unrolling
    for (layer, cell) in enumerate(R.rhn_cells)
        println("Layer: $layer")
        #_noise_i = reshape(noise_i[:, :, layer], (size(noise_i, 1), size(noise_i, 2)))
        #_noise_h = reshape(noise_h[:, :, layer], (size(noise_h, 1), size(noise_h, 2)))

        state = states[layer]
        outputs = []
        for timestep in 1:R.num_steps
            println("Timestep: $timestep")
            state = cell(inputs[timestep], state)#, _noise_i, _noise_h)
            push!(outputs, state)
        end

        # Reshape all the outputs to add an aditional dimension.
        inputs = outputs 
    end

    # Collect everything and apply a loss function
    reshaped = map(x -> reshape(x, size(x)..., 1), inputs) 
    reshaped = reduce((x,y) -> cat(x, y; dims = 3), reshaped)
    #reshaped = cat(map(x -> reshape(x, size(x)..., 1), inputs)...; dims = 3)
    #output = reshaped .* broadcast(noise_o, size(reshaped); axes = 3)
    output = reshape(reshaped, :, size(embedding, 1))
    #softmax_w = transpose(embedding)

    @show size(output)
    @show size(embedding)

    # TODO: Loss function not implemented correctly.
    # Just doing this to obtain preliminary results.
    logits = log.(max.(output * embedding, Float32(1e-9)))
    targets_expanded = broadcast(reshape(targets, :), size(logits); axes = 2)
     
    return Flux.crossentropy(reshape(logits, :), reshape(targets_expanded, :))
end

#####
##### Test Routines
#####

function rhn_cell_tester(;
        input_size = 1000, 
        hidden_size = 1000,
        depth = 10,
        batchsize = 16
    )

    R = RHNCell(input_size, hidden_size, depth)

    input = rand(Float32, input_size, batchsize)
    state = rand(Float32, hidden_size, batchsize)
    #noise_i = rand(Float32, input_size, batchsize)
    #noise_h = rand(Float32, hidden_size, batchsize)

    args = (input, state)#, noise_i, noise_h)

    backend = nGraph.Backend()
    tensors = nGraph.Tensor.(Ref(backend), args)
    f = nGraph.compile(R, tensors...)

    return f
end

function rhn_model_tester(;
        num_layers = 2,
        depth = 4,
        num_steps = 35,
        hidden_size = 1000,
        batch_size = 16,
        vocab_size = 10000,
    )

    ##### Create input arrays
    input_data = rand(Float32, hidden_size, batch_size, num_steps) 
    targets = rand(Float32, batch_size, num_steps)
    #noise_x = rand(Float32, batch_size, num_steps)
    #noise_i = rand(Float32, hidden_size, batch_size, num_layers)
    #noise_h = rand(Float32, hidden_size, batch_size, num_layers)
    #noise_o = rand(Float32, hidden_size, batch_size)
    states = zeros(Float32, hidden_size, batch_size, num_layers)

    R = rhn_model(
        num_layers = num_layers,
        depth = depth,
        num_steps = num_steps,
        hidden_size = hidden_size,
        batch_size = batch_size,
        vocab_size = vocab_size
    )

    println("Model Materialized")

    args = (input_data, targets, states)#, noise_x, noise_i, noise_h, noise_o)
    backend = nGraph.Backend()

    tensor_args = nGraph.Tensor.(Ref(backend), args)
    f = nGraph.compile(R, tensor_args...; optimizer = nGraph.SGD(Float32(0.001)))

    return f, tensor_args
end
