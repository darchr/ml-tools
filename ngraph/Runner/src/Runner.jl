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
using RecipesBase, Plots
using LightGraphs
using IterTools
using ProgressMeter
using TimerOutputs
using DataStructures

# Import some names
import nGraph: TensorDescriptor, NodeDescriptor, inputs, outputs, description

# Global Timer
const TO = TimerOutput()

@enum TensorLocation::UInt8 DRAM PMEM

"""
Location information for the input and output tensors of a node.
"""
struct IOConfig{N, M}
    inputs::NTuple{N, TensorLocation}
    outputs::NTuple{M, TensorLocation}
end

Base.iterate(io::IOConfig, args...) = iterate(Iterators.flatten((io.inputs, io.outputs)), args...)
Base.length(io::IOConfig{N,M}) where {N,M} = N + M
function Base.getindex(io::IOConfig{N,M}, idx::Integer) where {N,M}
    if idx <= N
        return io.inputs[idx]
    elseif idx <= length(io)
        return io.outputs[idx - N]
    else
        throw(BoundsError(io, idx))
    end
end

function setindex(io::IOConfig{N,M}, idx::Integer, x::TensorLocation) where {N,M}
    if idx <= N
        inputs = ntuple(i -> i == idx ? x : io.inputs[i], N)
        outputs = io.outputs
    elseif idx <= length(io)
        idx = idx - length(io.inputs)
        inputs = io.inputs
        outputs = ntupls(i -> i == idx ? x : io.outputs[i], M)
    end
    return IOConfig{N,M}(inputs, outputs)
end

function Base.isless(a::IOConfig{N,M}, b::IOConfig{N,M}) where {N,M}
    return (a.inputs < b.inputs) || ((a.inputs == b.inputs) && a.outputs < b.outputs)
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

include("metagraph.jl")
include("setup.jl")
include("types.jl")
include("util.jl")
include("opt/opt.jl")
include("models/simple.jl")
include("profiler/profile.jl")
include("verifier.jl")

# Analysis routines
include("analysis/correlations.jl")

# visualization routines
include("visualizer/reuse.jl")
include("visualizer/performance_plots.jl")
include("visualizer/allocation_plots.jl")
include("visualizer/statistics_plots.jl")
include("visualizer/analysis.jl")

# top level entry for scripts
include("top.jl")

JuMP.name(n::nGraph.NodeLike) = nGraph.name(n)

hasprofile(op_description::String) = !in(op_description, ("Parameter", "Constant", "Result", "Move"))
hasprofile(op::nGraph.Node) = hasprofile(nGraph.description(op))
hasprofile(x::NodeDescriptor) = hasprofile(nGraph.description(x))

ismove(description::String) = startswith(description, "Move")
ismove(op::nGraph.Node) = ismove(nGraph.description(op))
ismove(x::NodeDescriptor) = ismove(nGraph.description(x))

isconstant(description::String) = startswith(description, "Constant")
isconstant(x::nGraph.Node) = isconstant(nGraph.description(x))
isconstant(x::NodeDescriptor) = isconstant(nGraph.description(x))

# TODO: These might not be perfect ...
isparam(t::NodeDescriptor) = startswith(nGraph.description(t), "Parameter")
isresult(t::NodeDescriptor) = startswith(nGraph.description(t), "Result")

end # module
