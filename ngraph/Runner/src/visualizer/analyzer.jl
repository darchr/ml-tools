# Put this into a module to help namespaces be less crazy.
module Analyzer

import ..Runner
import ..Runner: IOConfig, nodes, unwrap, TensorWrapper, live_tensors, is_persistent,
    inputs, outputs, tensors
using nGraph
using RecipesBase
using Plots

include("marginal.jl")
#####
##### Reuse Distance
#####

struct ReuseDistance
    data::Dict{TensorWrapper, Int64}
end

function reuse_distance(fex::nGraph.FluxExecutable, data::Runner.ProfileData)
    tensor_to_tensors = Dict{TensorWrapper, Set{TensorWrapper}}()
    for tensors in live_tensors(data)
        for tensor in tensors
            s = get!(tensor_to_tensors, tensor, Set{TensorWrapper}())
            union!(s, tensors)
        end
    end
    return ReuseDistance(Dict(k => sum(sizeof.(v)) for (k,v) in tensor_to_tensors))
end

@recipe function f(rd::ReuseDistance)
    legend := :none
    linewidth := 0
    marker := :o
    xlabel := "Reuse Distance (MiB)"
    ylabel := "Tensor Size (MiB)"

    @series begin
        seriestype = :scatter 
        markerstrokealpha := 0.0

        # x values are the reuse distance
        # y values are the size of the tensor
        # color denotes PMEM vs DRAM
        x = Float64[]
        y = Float64[]
        colors = Symbol[]  
        for (tensor, distance) in rd.data
            push!(x, distance)
            push!(y, sizeof(tensor))
            push!(colors, nGraph.is_persistent(unwrap(tensor)) ? :red : :blue)
        end
        c := colors

        # Rescale
        x .= x ./ 1E6
        y .= y ./ 1E6
        x, y
    end
end

#####
##### Kernel Analyzer
#####

struct Kernel
    params::Runner.CPUKernelParams
    index::Int
    config::IOConfig
end

description(K::Kernel) = K.params.description

# IO Breakdown.
# The goal of this routine is to take ngraph function, group the operations by type
# and then plot it as a bargraph
function kernel_breakdown(fex::nGraph.FluxExecutable)
    kernels = Kernel[]
    for (index, node) in enumerate(fex.ex.ngraph_function)
        config = Runner.getconfig(node)
        params = Runner.CPUKernelParams(node)
        # Get the entry for this kernel, creating it if it doesn't exist yet.
        push!(kernels, Kernel(params, index, config))
    end
    return kernels
end


struct KernelPlot{NR,NC,X,Y,C,T}
    kernels::Vector{Kernel}
    # Functions for various subplotting routines
    nrows::NR
    ncols::NC
    x::X
    y::Y
    color::C
    title::T
end

@recipe function f(_plot::KernelPlot)
    # Unpack some things 
    kernels = _plot.kernels 

    num_rows = _plot.nrows(kernels)
    num_cols = _plot.ncols(kernels)

    # Setup default plot settings
    layout := (num_rows, num_cols)
    seriestype := :scatter
    legend := :none
    xlabel := "Size (MiB)"
    markerstrokealpha := 0.0
    xrotation := 60

    #size := (200 * num_rows, 500 * num_cols)
    sz = (150 * num_cols, 300 * num_rows) 
    size := sz

    for row in 1:num_rows
        for col in 1:num_cols
            @series begin
                subplot := col
            
                x = _plot.x(kernels, row, col)
                y = _plot.y(kernels, row, col)
                c := _plot.color(kernels, row, col)
                title := _plot.title(kernels, row, col)

                # rescale
                x = x ./ 1E6

                x, y
            end
        end
    end
end

end
