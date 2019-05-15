#####
##### Datatype for Tensors
#####

struct Tensor{T,P}
    size::Int64
    islive::Bool
    users::Vector{T}
    pools::Vector{P}
end

_producer(T::Tensor) = first(T.users)
_lastuser(T::Tensor) = last(T.users)
_users(T::Tensor) = T.users

Base.sizeof(T::Tensor) = T.size
islive(T::Tensor) = T.islive

_liverange(T::Tensor) = _index(_producer(T)):_index(_consumer(T))

#####
##### Datatypes for Kernels
#####

# Types of objective function emitters
abstract type AbstractKernelObjective end

# Look-up-table for node costs based on runtimes
struct KernelLUT{T} <: AbstractKernelObjective
    data::Dict{T,Float64}
end

struct Kernel{K <: AbstractKernelObjective, P}
    # This kernel's index in the computation graph
    index::Int
    inputs::Vector{Tensor{Kernel, P}}
    outputs::Vector{Tensor{Kernel, P}}

    # The type of objective function to use
    objective::K

    # New and freed tensors from liveness analysis
    tensor_newlist::Vector{Tensor{Kernel, P}}
    tensor_freelist::Vector{Tensor{Kernel, P}}
end

_inputs(K::Kernel) = K.inputs
_outputs(K::Kernel) = K.outputs
_index(K::Kernel) = K.index


#####
##### Computation Graph
#####

struct ComputationGraph{T <: Tensor, K <: Kernel}
    tensors::Vector{T} 
    kernels::Vector{K}
end

function ComputationGraph(tensors::Vector{T}, kernels::Vector{K}) where {T,K}
    # Perform liveness analysis on the tensors + kernels
    freed_tensors = Set{eltype(tensors)}()

    # Forward pass
    for kernel in kernels, tensor in outputs(kernel)
        if islive(tensor)
            push!(kernel.tensor_newlist, tensor)
        end
    end

    # Backward pass
    for kernel in reverse(kernels), tensor in inputs(kernel) 
        if islive(tensor) && !in(tensor, freed_tensors)
            push!(kernel.tensor_freelist, tensor)
            push!(freed_tensors, tensor)
        end
    end

    # Done
    return ComputationGraph{T,K}(tensors, kernels)
end

tensortype(G::ComputationGraph{T,K}) where {T,K} = T
kerneltype(G::ComputationGraph{T,K}) where {T,K} = K

tensors(G::ComputationGraph) = G.tensors
tensors(G::ComputationGraph, ind...) = G.tensors[ind...]

kernels(G::ComputationGraph) = G.kernels
kernels(G::ComputationGraph, ind...) = G.kernels[ind...]
