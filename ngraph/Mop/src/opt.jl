#####
##### Types for controlling the overall formulation
#####

abstract type AbstractModelType end

struct Static <: AbstractModelType
    limit::Int64
end

#####
##### Tensor Metadata
#####

struct TensorMeta
    graph::MetaGraph
    reference_map::Dict{Int,Int}
end

#####
##### Frame
#####

# The frame holdes all the preprocessing information as well as the JuMP model
mutable struct Frame{M <: AbstractModelType, G <: ComputationGraph, T <: Tensor}
    model_type::M
    graph::G
    jump_model::JuMP.Model

    # Misc Data Structures
    tensor_meta::Dict{T, TensorMeta} 
end

function Frame(model_type::AbstractModelType, graph::ComputationGraph, jump_model)
    # Forward arguments, using an empty tensor meta dictionary
    frame = Frame(model_type, graph, jump_model, Dict{tensortype(graph), TensorMeta}())

    # Populate the tensor graphs
    preprocess!(frame) 

    return frame
end

function preprocess!(frame::Frame)
    graph = frame.graph
    for tensor in tensors(graph)
        reference_map = _reference_map(frame.model_type, graph, tensor)
    end
end

## Reference Maps
function _reference_map(::Static, graph, tensor)
    liverange = _liverange(tensor)
    producer = _producer(tensor)
    map = Dict{Int,Int}()
    for i in liverange
        map[_index(kernels(graph, i))] = _index(producer)
    end
    return map
end

#####
##### Entry Point
#####

function create(model_type::AbstractModelType, graph::ComputationGraph)
    # TODO: Make optimizer an argument
    jump_model = Model(with_optimizer(Gurobi.Optimizer; TimeLimit = 60, MIPGap = 0.0003))
    frame = Frame(model_type, graph, jump_model)

    return frame
end
