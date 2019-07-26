# Oh boy. Here we go
function lstm_test()
    timesteps = 50
    hiddensize = 1000
    batchsize = 16

    x = rand(Float32, hiddensize, timesteps * batchsize)

    lstm = nGraph.RnnLSTM(hiddensize, hiddensize, nGraph.FORWARD, 50)
    return lstm, (x,), NamedTuple()
end

function lstm_bidir_test()
    timesteps = 50
    hiddensize = 1000
    batchsize = 16

    x = rand(Float32, hiddensize, timesteps * batchsize)

    lstm = nGraph.RnnLSTM(hiddensize, hiddensize, nGraph.BIDIRECTIONAL, 50)
    return lstm, (x,), NamedTuple()
end

struct GNMTParams
    hiddensize::Int64
    num_timesteps::Int64
    num_layers::Int64
    batchsize::Int64
end

function gnmt_encoder_test()
    p = GNMTParams(1000, 50, 8, 16)

    x = rand(Float32, p.hiddensize, p.num_timesteps * p.batchsize)
    return GNMTEncoder(p), (x,), NamedTuple() 
end

function lstm_backprop_test()
    p = GNMTParams(1000, 50, 8, 16)

    x = rand(Float32, p.hiddensize, p.num_timesteps * p.batchsize)

    forward = GNMTEncoder(p)
    f = (x) -> sum(forward(x))
    kw = (optimizer = nGraph.SGD(Float32(0.001)),)
    return f, (x,), kw
end


#####
##### Encoder
#####

struct GNMTEncoder
    first
    second
    rest::Vector
end

function GNMTEncoder(p::GNMTParams)
    # First bidirectional lstm layer
    first = nGraph.RnnLSTM(p.hiddensize, p.hiddensize, nGraph.BIDIRECTIONAL, p.num_timesteps)

    # 2nd layer with 2x larger input size
    second = nGraph.RnnLSTM(2 * p.hiddensize, p.hiddensize, nGraph.FORWARD, p.num_timesteps)    

    # Remaining LSM Layers
    rest = []
    for _ in 1:p.num_layers - 2
        push!(rest,
            nGraph.RnnLSTM(p.hiddensize, p.hiddensize, nGraph.FORWARD, p.num_timesteps)    
        )
    end

    return GNMTEncoder(first, second, rest)
end

function (G::GNMTEncoder)(x)
    x = first(G.first(x))
    x = first(G.second(x))
    for layer in G.rest
        x = first(layer(x)) + x
    end

    return x
end

#####
##### Attention
#####

# struct GNMTAttention
#     linear_q
#     linear_k
#     linear_att
#     normalize_scalar
#     normalize_bias
# end
# 
# function (A::GNMTAttention)(query, keys)
# end


#####
##### GNMT Decoder
#####

struct GNMTDecoder
    recurrent_attention
    classifier
    layers 
end

function GNMTDecoder(p::GNMTParams)

end

