# Location information. Specify whether paths are supposed to be on the host computer or
# on the container.
abstract type Location end
struct OnHost <: Location end
struct OnContainer <: Location end

## Workloads
abstract type AbstractWorkload end

startfile(::T, ::Type{L}) where {T <: AbstractWorkload, L <: Location} = error("""
    Startfile not defined for workload type $T on location $L
    """)

runcommand(::T) where T = `$(startfile(T, OnContainer))`

## Concrete model
include("cifar_cnn.jl")
include("cifar_resnet.jl")
