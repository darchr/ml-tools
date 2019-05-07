# Put this into a module to help namespaces be less crazy.
module Analyzer

import ..Runner
import ..Runner: IOConfig, nodes, unwrap
using nGraph
using RecipesBase
using PrettyTables
using Plots

struct Kernel
    params::Runner.CPUKernelParams
    index::Int
    config::IOConfig
end

description(K::Kernel) = K.params.description

# Tables stuff
hl_pmem() = Highlighter((data,i,j) -> (data[i,j] == Runner.PMEM); foreground = :red)
hl_dram() = Highlighter((data,i,j) -> (data[i,j] == Runner.DRAM); foreground = :green)

function showtable(kernels::Vector{Kernel})
    # Make all the configs into a table
    config_table = vcat(makearray.(k.configs for k in kernels)...)
    showtable(config_table)
end

showtable(configs::Vector{T}) where {T <: IOConfig} =
    pretty_table(makearray(configs), headers(first(configs)); highlighters = (hl_pmem(), hl_dram()))

makearray(configs::Vector{IOConfig}) = vcat(permutedims.(collect.(configs))...)
headers(::T) where {T <: IOConfig} = headers(T)
headers(::Type{IOConfig{N,M}}) where {N,M} = vcat(
    ["input $i" for i in 1:N],
    ["output $i" for i in 1:M]
)

# IO Breakdown.
# The goal of this routine is to take ngraph function, group the operations by type
# and then plot it as a bargraph
function kernel_breakdown(fex::nGraph.FluxExecutable)
    pd = Runner.ProfileData(fex)

    kernels = Kernel[]
    for (index, node) in enumerate(nodes(pd))
        config = Runner.getconfig(unwrap(node))
        params = Runner.CPUKernelParams(unwrap(node))
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

    for row in 1:num_rows
        for col in 1:num_cols
            @series begin
                subplot := col
            
                x = _plot.x(kernels, row, col)
                y = _plot.y(kernels, row, col)
                c := _plot.color(kernels, row, col)
                title := _plot.title(kernels, row, col)

                @show x
                @show y
                
                x, y
            end
        end
    end
end



end
