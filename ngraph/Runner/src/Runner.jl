module Runner

function __init__()
    Runner.setup_affinities()
    Runner.setup_profiling()
    Runner.setup_pmem()
    Runner.setup_passes()
end

# stdlibs
using Dates, Random, Serialization, Statistics

# deps
using nGraph, Flux, JSON
using JuMP, Gurobi
using RecipesBase
using LightGraphs, MetaGraphs
using IterTools
using ProgressMeter

@enum TensorLocation::UInt8 DRAM PMEM

"""
Location information for the input and output tensors of a node.
"""
struct IOConfig{N, M}
    inputs::NTuple{N, TensorLocation}
    outputs::NTuple{M, TensorLocation}
end

function Base.show(io::IO, config::IOConfig{N,M}) where {N,M}
    f = x -> (x == DRAM) ? "DRAM" : "PMEM"
    print(io, "IOConfig{$N,$M}: ")
    print(io, "(", join(f.(config.inputs), ", "), ") -- ")
    print(io, "(", join(f.(config.outputs), ", "), ")")
end

#####
##### Local Includes
#####

include("setup.jl")
include("types.jl")
include("util.jl")
include("opt/opt.jl")
include("models/simple.jl")
include("profiler/profile.jl")
include("visualize.jl")
include("verifier.jl")

keep(op_description::String) = !in(op_description, ("Parameter", "Constant", "Result", "Move"))
keep(op::nGraph.Node) = keep(nGraph.description(op))

end # module
