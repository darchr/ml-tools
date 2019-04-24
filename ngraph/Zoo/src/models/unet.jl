#####
##### DeConv layer
#####
# 
# Like a normal Flux Conv layer, but only really implements the correct forward pass for
# ngraph Nodes


struct DeConv{N,F,A,V,N2}
    σ::F
    weight::A
    bias::V
    out_size::NTuple{N2,Int}
    stride::NTuple{N,Int}
    pad::NTuple{N,Int}
    dilation::NTuple{N,Int}
end

DeConv(w::AbstractArray{T,N}, b::AbstractVector{T}, out_size, σ = identity;
     stride = 1, pad = 0, dilation = 1) where {T,N} =
  DeConv(σ, w, b, out_size, Flux.expand.(Flux.sub2(Val(N)), (stride, pad, dilation))...)

DeConv(k::NTuple{N,Integer}, ch::Pair{<:Integer,<:Integer}, out_size, σ = identity;
     init = Flux.glorot_uniform,  stride = 1, pad = 0, dilation = 1) where N =
  DeConv(Flux.param(init(k..., ch...)), Flux.param(zeros(Float32, ch[2])), out_size, σ;
       stride = stride, pad = pad, dilation = dilation)

Flux.@treelike DeConv

function (c::DeConv)(x::AbstractArray{T,N}) where {T,N}
    cn = nGraph.deconvolution(
        nGraph.Node(x), 
        nGraph.Node(c.weight), 
        c.out_size;
        stride = c.stride, 
        pad = c.pad, 
        dilation = c.dilation
    ) 

    axis_set = [collect(1:N-2); N]
    bb = broadcast(nGraph.Node(c.bias), size(cn); axes = axis_set)
    
    return (c.σ)(cn .+ bb)
end

#####
##### UNet functions
#####

function temp(batchsize)
    Chain(
          MaxPool((2,2,2); pad = 0, stride = 2),
          Conv((3,3,3), 256 => 256, relu; pad = 1),
          Conv((3,3,3), 256 => 512, relu; pad = 1),
          DeConv((2,2,2), 512 => 512, (33, 33, 29, 512, batchsize), identity; pad = 0, stride = 2),
    )
end



function splice_scale(a, b, c, d, e, f, dims, middle)
    C1 = Chain(
        MaxPool((2,2,2); pad = 0, stride = 2),
        Conv((3,3,3), a => b, relu; pad = 1),
        Conv((3,3,3), b => c, relu; pad = 1),
    )
    C2 = Chain(
        Conv((3,3,3), d => e, relu; pad = 1),
        Conv((3,3,3), e => f, relu; pad = 1),
        DeConv((2,2,2), f => f, dims, identity; pad = 0, stride = 2)
    )

    return function(x)
        A = C1(x)
        @show size(A)
        B = middle(A)
        C = C2(cat(A, B; dims = 4))
        @show size(C)
        return C
    end
end

function splice(a, b, c, d, e, f, middle)
    C1 = Chain(
        Conv((3,3,3), a => b, relu; pad = 1),
        Conv((3,3,3), b => c, relu; pad = 1),
    )
    C2 = Chain(
        Conv((3,3,3), d => e, relu; pad = 1),
        Conv((3,3,3), e => f, relu; pad = 1),
    )
    return function(x)
        A = C1(x)
        @show size(A)
        B = middle(A)
        return C2(cat(A, B; dims = 4))
    end
end

function _unet(batchsize)
    println("Middle")
    middle = temp(batchsize)

    println("Layer 1")
    middle = splice_scale(128, 128, 256, 256+512, 256, 256, (66, 66, 58, 256, batchsize), middle)

    println("Layer 2")
    middle = splice_scale(64, 64, 128, 128 + 256, 128, 128, (132, 132, 116, 128, batchsize), middle)

    println("Layer 3")
    f = splice(3, 32, 64, 64 + 128, 64, 64, middle)
    println("Final Layer")

    return Chain(
        f,
        Conv((1,1,1), 64 => 3; pad = 0),
        x -> log.(max.(x, Float32(1e-9))),
        x -> softmax(x; axes = 3)
    )
end

__crossentropy(a, b) = -sum(b .* log.(a)) // size(b, 3)

function unet_training(batchsize = 1)
    backend = nGraph.Backend()
    x = rand(Float32, 132, 132, 116, 3, batchsize)
    x = (x .- mean(x)) ./ std(x)

    y = zeros(Float32, 132, 132, 116, 3, batchsize)
    #for (i,j,k,b) in CartesianIndices((132, 132, 16, batchsize))
    for ci in CartesianIndices((44, 44, 28, batchsize))
        i, j, k, b = Tuple(ci)
        y[i, j, k, rand(1:3), b] = one(eltype(y))
    end

    X = nGraph.Tensor(backend, x)
    Y = nGraph.Tensor(backend, y)

    model = _unet(batchsize)

    f(x, y) = __crossentropy(model(x), y)

    fex = nGraph.compile(f, X, Y; optimizer = nGraph.SGD(Float32(0.001)))
    return fex, (X,Y)
end
