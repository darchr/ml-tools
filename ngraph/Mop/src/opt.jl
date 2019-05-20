@enum EdgeMeta begin
    EDGE_NONE 
    EDGE_CREATE 
    EDGE_CREATE 
    EDGE_DESTROY 
    EDGE_SYNC_WRITE 
    EDGE_SYNC_READ
    EDGE_ASYNC_WRITE
    EDGE_ASYNC_READ
end

@enum VertexType VERTEX_SYNC VERTEX_ASYNC VERTEX_NONE

struct VertexMeta
    gadget::Int
    pool::MemoryPool
    vertex_type::VertexType
end

#####
##### Tensor Metadata
#####
struct TensorGraph{K}
    graph::LightGraphs.SimpleDiGraph{Int64}
    # Annotations on edge types
    edge_meta::Dict{SimpleEdge{Int64}, EdgeMeta}
    # Mapping of vertices to Kernels that that node represents.
    gadget_to_kernel::Vector{K}
    kernel_move_type::Dict{K, VertexType}

    vertex_meta::Vector{VertexMeta}
    rev_vertex_meta::Dict{VertexMeta, Int64}
end

function LightGraphs.add_vertex!(T::TensorGraph, kernel, gadget, pool, vertex_type)
    success = add_vertex!(T.graph)
    v = nv(T.graph)
    meta = VertexMeta(kernel, gadget, pool, vertex_type)
    push!(T.vertex_meta, meta)
    T.vertex_meta[meta] = v
    return success
end

function Base.getindex(T::TensorGraph{P}, gadget::Int, pool) where {P}
    g = T.gadgets[gadget] 
    i = findfirst(x -> x.pool == pool, g)
    return g[i]
end

kernel(T::TensorGraph, gadget) = T.vertex_meta[first(T.gadgets[gadget])].kernel


#####
##### Frame
#####

# The frame holdes all the preprocessing information as well as the JuMP model
mutable struct Frame{G <: ComputationGraph, T <: Tensor, K}
    graph::G
    jump_model::JuMP.Model

    # Misc Data Structures
    tensor_meta::Dict{T, TensorMeta{K}}
end

function Frame(graph::ComputationGraph, jump_model)
    # Forward arguments, using an empty tensor meta dictionary
    frame = Frame(graph, jump_model, Dict{tensortype(graph), TensorMeta}())

    # Populate the tensor graphs
    preprocess!(frame) 

    return frame
end

function preprocess!(frame::Frame)
    graph = frame.graph
    for tensor in tensors(graph)
        # Get the producer, consumer, and all possible moves for this tensor.
        # Sort the resulting list by node index so the gadgest traverse the nodes
        # in program order.
        producer = _producer(tensor)
        lastuser = _lastuser(tensor)

        gadget_nodes = vcat(
            [producer, lastuser],
            tensor.sync_moves, 
            tensor.async_moves
        )
        unique!(gadget_nodes)
        sort!(gadget_nodes; by = x -> _index(x))

        # Create the tensor graph
        g = DiGraph()
        gadgets = Vector{Int64}[]
        # TODO: Type this
        vertex_meta = []
        for (gadget_index, node) in enumerate(gadget_nodes)
            this_gadget = Int64[]

            # Add a vertex for each memory pool where this tensor may live.
            for pool in _pools(tensor)
                add_vertex!(g)
                push!(this_gadget, nv(g))
                push!(vertex_meta, VertexMeta(_index(node), gadget_index, pool))
            end

            # Create source or sink nodes.
            if in(node, (producer, lastuser))
                add_vertex!(g)
                push!(this_gadget, nv(g))
                loc = node == producer ? SOURCE : SINK
                push!(vertex_meta, VertexMeta(_index(node), gadget_index, loc))
            end
        end

        tensor_graph = TensorGraph(g, Dict{SimpleEdge{Int64}, EdgeMeta}(), vertex_meta, gadgets)

        # Add edges
    end
end

#####
##### Entry Point
#####

function create(graph::ComputationGraph)
    # TODO: Make optimizer an argument
    jump_model = Model(with_optimizer(Gurobi.Optimizer; TimeLimit = 60, MIPGap = 0.0003))
    frame = Frame(graph, jump_model)

    return frame
end
