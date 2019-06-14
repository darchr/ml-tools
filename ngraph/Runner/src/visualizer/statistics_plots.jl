getname(v, s::Symbol) = getindex.(v, s)

function stats_plot(f)
    savefile = joinpath(savedir(f), join((name(f), "synchronous"), "_") * ".jls")
    data = deserialize(savefile)

    # Setup global parameters for plotting
    size = (1000, 1000)
    font = Plots.font("Helvetica", 15)

    # Plot the number of move nodes.
    io_size = data.io_size[] 
    dram_sizes = (getname(data.runs, :dram_limit) ./ 1E3) .+ (io_size ./ 1E9)

    x = [dram_sizes, dram_sizes]
    y = [
        getname(data.runs, :bytes_moved_pmem) ./ 1E6,
        getname(data.runs, :bytes_moved_dram) ./ 1E6,
    ]

    plt = plot(
        x, 
        y, 
        lab = ["Moved to PMEM", "Moved to DRAM"],
        xlabel = "DRAM Size (GiB)",
        ylabel = "MiB of Memory Moved",
        title = titlecase(replace(name(f), "_" => " ")),
        legend = :bottomleft,
        linewidth = 5,
        marker = :x,
        markersize = 10,
        left_margin = 20mm,
        right_margin = 20mm,
        bottom_margin = 10mm,
        xtickfont = font,
        ytickfont = font,
        legendfont = font,
        size = size,
    )
    # overlay y axis
    subplt = twinx()

    x = dram_sizes
    y = getname(data.runs, :bytes_dram_input_tensors) ./ getname(data.runs, :bytes_input_tensors)
    plot!(subplt, x, y,
        linewidth = 5,
        legend = :right,
        marker = :o,
        markersize = 10,
        color = :blue,
        lab = "Percent of Input Tensors in DRAM (R)",
        xtickfont = font,
        ytickfont = font,
        legendfont = font,
    )

    # Plot the percent of output tensors in DRAM @series begin
    x = dram_sizes
    y = getname(data.runs, :bytes_dram_output_tensors) ./ getname(data.runs, :bytes_output_tensors)

    @show getname(data.runs, :bytes_dram_output_tensors)
    @show getname(data.runs, :bytes_output_tensors)
    @show getname(data.runs, :num_dram_output_tensors)
    @show getname(data.runs, :num_output_tensors)

    plot!(subplt, x, y,
        linewidth = 5,
        marker = :square,
        markersize = 10,
        color = :red,
        lab = "Percent of Output Tensors in DRAM (R)"
   )

    return plt
end

function pgf_stats_plot(f; file = "plot.tex")
    savefile = joinpath(savedir(f), join((name(f), "asynchronous"), "_") * ".jls")
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

    axs = @pgf Axis(
        {
            grid = "major",
            xlabel = "DRAM Limit (GB)",
            ylabel = "Memory Moved (GB)",
        },
        PlotInc(
             {
                thick,
             },
             Coordinates(x, getname(data.runs, :bytes_moved_pmem) ./ 1E9)
        ),
        LegendEntry("sync DRAM to PMEM"),
        PlotInc(
             {
                thick,
             },
             Coordinates(x, getname(data.runs, :bytes_moved_dram) ./ 1E9)
        ),
        LegendEntry("sync PMEM to DRAM"),
        PlotInc(
             {
                thick,
             },
             Coordinates(x, getname(data.runs, :bytes_async_moved_pmem) ./ 1E9)
        ),
        LegendEntry("async DRAM to PMEM"),
        PlotInc(
             {
                thick,
             },
             Coordinates(x, getname(data.runs, :bytes_async_moved_dram) ./ 1E9)
        ),
        LegendEntry("async PMEM to DRAM"),
    )

    push!(plot, TikzPicture(axs))

    empty!(PGFPlotsX.CUSTOM_PREAMBLE)
    push!(PGFPlotsX.CUSTOM_PREAMBLE, "\\usepgfplotslibrary{colorbrewer}")

    pgfsave(file, plot)

    return nothing
end

function pgf_io_plot(f; file = "plot.tex")
    savefile = joinpath(savedir(f), join((name(f), "asynchronous"), "_") * ".jls")
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
        },
        PlotInc(
             {
                thick,
             },
             Coordinates(
                x, 
                getname(data.runs, :bytes_dram_input_tensors) ./ getname(data.runs, :bytes_input_tensors)
            )
        ),
        LegendEntry("input tensors"),
        PlotInc(
             {
                thick,
             },
             Coordinates(
                x, 
                getname(data.runs, :bytes_dram_output_tensors) ./ getname(data.runs, :bytes_output_tensors)
            )
        ),
        LegendEntry("output tensors"),
    )

    push!(plot, TikzPicture(axs))

    empty!(PGFPlotsX.CUSTOM_PREAMBLE)
    push!(PGFPlotsX.CUSTOM_PREAMBLE, "\\usepgfplotslibrary{colorbrewer}")

    pgfsave(file, plot)

    return nothing
end



