# Location information. Specify whether paths are supposed to be on the host computer or
# on the container.
abstract type Location end
struct OnHost <: Location end
struct OnContainer <: Location end

## Workloads
#
"""
Abstract supertype for workloads. Concrete subtypes should be implemented for each workload
desired for analysis.
"""
abstract type AbstractWorkload end


const WORKLOADS = joinpath(MLTOOLS, "workloads")

"""
    startfile(work::AbstractWorkload, ::Type{OnHost}) -> String

Return the path of the entrypoint file of `work` on the host machine.

    startfile(work::AbstractWorkload, ::Type{OnContainer}) -> String

Return the path of the entrypoint file of `work` on the Docker Container.
"""
startfile(::T, ::Type{L}) where {T <: AbstractWorkload, L <: Location} = error("""
    Startfile not defined for workload type $T on location $L
    """)


"""
    runcommand(work::AbstractWorkload) -> Cmd

Return the Docker Container entry command for `work`.
"""
runcommand(::T) where {T <:AbstractWorkload} = `$(startfile(T, OnContainer))`

"""
    create(work::AbstractWorkload; kw...) -> Container

Create a Docker Container for `work`, with optional keyword arguments. Concrete subtypes
of `AbstractWorkload` must define this method and perform all the necessary steps
to creating the Container. Note that the container should just be created by a call
to `DockerX.create_container`, and not actually started.

Keyword arguments supported by `work` should be included in that types documentation.
"""
create(work::AbstractWorkload; kw...)

## Concrete model
include("ubuntu/test.jl")
include("keras/cifar_cnn.jl")
include("tensorflow/resnet.jl")
include("tensorflow/slim.jl")
