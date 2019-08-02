function pgf_error_plot(fns, ratios; file = "plot.tex", formulations = ("static", "synchronous"))
    
    plots = []
    for formulation in formulations
        for f in fns
            x = []
            y = []
            data = load_save_files(f, formulation)

            for ratio in ratios
                ind = findabsmin(x -> compare_ratio(getratio(x), ratio), data.runs)
                actual_runtime = data.runs[ind][:actual_runtime]
                predicted_runtime = data.runs[ind][:predicted_runtime] / 1E6
                push!(x, ratio_string(ratio))
                push!(y, 100 * (predicted_runtime - actual_runtime) / actual_runtime)
            end

            append!(plots, [
                @pgf(PlotInc(Coordinates(x, y)))
                @pgf(LegendEntry("$(titlename(f)) - $formulation"))
            ])
        end
    end

    # Make the plot itself
    plt = TikzDocument()
    push!(plt, """
    \\pgfplotsset{
        width=12cm,
        height=8cm}
    """)

    axs = @pgf Axis(
        {
            ybar,
            bar_width = "5pt",
            grid = "major",
            xlabel = "DRAM Limit (GB)",
            ylabel = "Relative Predicted Runtime Error \\%",
            # Put the legend outside on the right
            legend_style = {
                at = Coordinate(1.05, 0.5),
                anchor = "west",
            },
            legend_cell_align = {"left"},

            # Setup x coordinates
            symbolic_x_coords = ratio_string.(ratios), 
        },
        plots...
    )

    push!(plt, TikzPicture(axs))
    pgfsave(file, plt)

    return nothing
end
