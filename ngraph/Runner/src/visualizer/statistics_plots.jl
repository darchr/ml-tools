#####
##### Plotting Utility Functions
#####

getname(v, s::Symbol) = getindex.(v, s)

_load_save_files(f, formulations::String) = _load_save_files(f, (formulations,))
function _load_save_files(f, formulations)
    savefiles = [joinpath(savedir(f), join((name(f), i), "_") * ".jls") for i in formulations]
    data = deserialize.(savefiles)
    for d in data
        sort!(d.runs; rev = true, by = x -> x[:dram_limit])
    end

    return data
end

# For drawing a vertical asymptote on a graph
vasymptote() = """
\\pgfplotsset{vasymptote/.style={
    before end axis/.append code={
        \\draw[densely dashed] ({rel axis cs:0,0} -| {axis cs:#1,0})
        -- ({rel axis cs:0,1} -| {axis cs:#1,0});
}
}}
"""

#####
##### The plots
#####

function pgf_stats_plot(f; file = "plot.tex", formulation = "synchronous")
    savefile = joinpath(savedir(f), join((name(f), formulation), "_") * ".jls")
    data = deserialize(savefile)

    # Plot the number of move nodes.
    io_size = data.io_size[] 
    dram_sizes = (getname(data.runs, :dram_limit) ./ 1E3) .+ (io_size ./ 1E9)

    x = dram_sizes

    plot = TikzDocument()
    scheme = "Spectral"
    plotsets = """
        \\pgfplotsset{
            cycle list/$scheme,
            cycle multiindex* list={
                mark list*\\nextlist
                $scheme\\nextlist
            },
        }
    """
    push!(plot, plotsets)
    push!(plot, vasymptote())

    plots = [
        @pgf(PlotInc(
             {
                thick,
             },
             Coordinates(x, getname(data.runs, :bytes_moved_pmem) ./ 1E9)
        )),
        @pgf(LegendEntry("sync DRAM to PMEM")),
        @pgf(PlotInc(
             {
                thick,
             },
             Coordinates(x, getname(data.runs, :bytes_moved_dram) ./ 1E9)
        )),
        @pgf(LegendEntry("sync PMEM to DRAM")),
    ]


    axs = @pgf Axis(
        {
            grid = "major",
            xlabel = "DRAM Limit (GB)",
            ylabel = "Memory Moved (GB)",
            vasymptote = data.default_alloc_size[] / 1E9,
        },
        plots...,
        # PlotInc(
        #      {
        #         thick,
        #      },
        #      Coordinates(x, getname(data.runs, :bytes_async_moved_pmem) ./ 1E9)
        # ),
        # LegendEntry("async DRAM to PMEM"),
        # PlotInc(
        #      {
        #         thick,
        #      },
        #      Coordinates(x, getname(data.runs, :bytes_async_moved_dram) ./ 1E9)
        # ),
        # LegendEntry("async PMEM to DRAM"),
    )

    push!(plot, TikzPicture(axs))

    empty!(PGFPlotsX.CUSTOM_PREAMBLE)
    push!(PGFPlotsX.CUSTOM_PREAMBLE, "\\usepgfplotslibrary{colorbrewer}")

    pgfsave(file, plot)

    return nothing
end

function pgf_io_plot(f; file = "plot.tex", formulations = "synchronous")
    data = _load_save_files(f, formulations)

    # Plot the number of move nodes.
    io_size = first(data).io_size[] 
    plots = []
    for (d, formulation) in zip(data, formulations)
        dram_sizes = (getname(d.runs, :dram_limit) ./ 1E3) .+ (io_size ./ 1E9)
        push!(plots, @pgf(
            PlotInc(
                 {
                    thick,
                 },
                 Coordinates(
                    dram_sizes, 
                    getname(d.runs, :bytes_dram_input_tensors) ./ getname(d.runs, :bytes_input_tensors)
                )
            ),
        ))
        push!(plots, @pgf(LegendEntry("$formulation: input tensors")))
        push!(plots, @pgf(PlotInc(
                 {
                    thick,
                 },
                 Coordinates(
                    dram_sizes, 
                    getname(d.runs, :bytes_dram_output_tensors) ./ getname(d.runs, :bytes_output_tensors)
                 )
            ),
        ))
        push!(plots, @pgf(LegendEntry("$formulation: output tensors")))
    end

    plot = TikzDocument()
    scheme = "Spectral"
    plotsets = """
        \\pgfplotsset{
            cycle list/$scheme,
            cycle multiindex* list={
                mark list*\\nextlist
                $scheme\\nextlist
            },
        }
    """
    push!(plot, plotsets)
    push!(plot, vasymptote())

    axs = @pgf Axis(
        {
            grid = "major",
            xlabel = "DRAM Limit (GB)",
            ylabel = "Percent of Kernel Arguments in DRAM",
            # put legend on the bottom right
            legend_style = {
                at = Coordinate(1.0, 0.0),
                anchor = "south east",
            },
            vasymptote = first(data).default_alloc_size[] ./ 1E9,
        },
        plots...
    )

    push!(plot, TikzPicture(axs))

    empty!(PGFPlotsX.CUSTOM_PREAMBLE)
    push!(PGFPlotsX.CUSTOM_PREAMBLE, "\\usepgfplotslibrary{colorbrewer}")

    pgfsave(file, plot)

    return nothing
end

function pgf_comparison_plot(f; file = "plot.tex", formulations = ("synchronous",))
    data = _load_save_files(f, formulations)
    
    plots = []
    for (d, formulation) in zip(data, formulations)
        dram_limit = getname(d.runs, :dram_limit) ./ 1E3
        actual_runtime = getname(d.runs, :actual_runtime)
        predicted_runtime = getname(d.runs, :predicted_runtime) ./ 1E6
        append!(plots, [
        @pgf(PlotInc(
             {
                thick,
             },
             Coordinates(
                dram_limit, 
                actual_runtime,
            )
        ))
        @pgf(LegendEntry("$formulation: actual"))
        @pgf(PlotInc(
             {
                thick,
             },
             Coordinates(
                dram_limit, 
                predicted_runtime,
            )
        ))
        @pgf(LegendEntry("$formulation: predicted"))
        ])
    end

    # Make the plot itself
    plot = TikzDocument()
    scheme = "Spectral"
    plotsets = """
        \\pgfplotsset{
            cycle list/$scheme,
            cycle multiindex* list={
                mark list*\\nextlist
                $scheme\\nextlist
            },
        }
    """
    push!(plot, plotsets)
    push!(plot, vasymptote())

    axs = @pgf Axis(
        {
            grid = "major",
            xlabel = "DRAM Limit (GB)",
            ylabel = "Runtime (s)",
            # put legend on the bottom right
            legend_style = {
                at = Coordinate(0.95, 0.95),
                anchor = "north east",
            },
            vasymptote = first(data).default_alloc_size[] ./ 1E9,
        },
        plots...
    )

    push!(plot, TikzPicture(axs))

    empty!(PGFPlotsX.CUSTOM_PREAMBLE)
    push!(PGFPlotsX.CUSTOM_PREAMBLE, "\\usepgfplotslibrary{colorbrewer}")

    pgfsave(file, plot)

    return nothing
end
