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

Required Methods
----------------
* [`create`](@ref)
* [`getargs`](@ref)
"""
abstract type AbstractWorkload end

# Path to the `workloads` directory in `ml-tools`
const WORKLOADS = joinpath(MLTOOLS, "workloads")

"""
    create(work::AbstractWorkload; kw...) -> Container

Create a Docker Container for `work`, with optional keyword arguments. Concrete subtypes
of `AbstractWorkload` must define this method and perform all the necessary steps
to creating the Container. Note that the container should just be created by a call
to `Docker.create_container`, and not actually started.

Keyword arguments supported by `work` should be included in that types documentation.
"""
create(work::AbstractWorkload; kw...)

"""
    getargs(work::AbstractWorkloads)

Return the commandline arguments for `work`. Falls back to `work.args`. Extend this method
for a workload if the fallback is not appropriate.
"""
getargs(work::AbstractWorkload) = work.args

"""
    filename(work::AbstractWorkload)

Create a filename for `work` based on the data type of `work` and the arguments.
"""
function filename(work::T, ext = "dat") where {T <: AbstractWorkload}
    args = getargs(work)
    argstring = join(makeargs(args; delim = "=", pre = ""), "-")
    typename = last(split("$T", "."))
    return join((typename, argstring, ext), "-", ".")
end

## Concrete model
include("test/test.jl")
include("cifar_cnn/cifar_cnn.jl")
include("slim/slim.jl")
include("rnn_translator/translator.jl")
include("inception/inception.jl")
