# Plot ratios of PMEM to DRAM on the x-axis.
function pgf_speedup(f, ratios::Vector{<:Rational}; 
        file = "plot.tex", 
        formulations = ("numa", "static", "synchronous")
    )

    data = load_save_files(f, formulations)
    pmm_performance = get_pmm_performance(data)
    dram_performance = get_dram_performance(data)

    plots = [] 
    for (datum, formulation) in zip(data, formulations)
        @show formulation

        # This x and y data point
        x = []
        y = []

        for ratio in ratios
            ind = findabsmin(x -> compare_ratio(getratio(x), ratio), datum.runs)

            @show convert(Float64, getratio(datum.runs[ind]))
            @show convert(Float64, ratio)
            @show convert(Float64, compare_ratio(getratio(datum.runs[ind]), ratio))
            perf = pmm_performance / datum.runs[ind][:actual_runtime]

            push!(x, ratio_string(ratio))
            push!(y, perf)
        end

        # Emit the plot for this series.
        append!(plots, [
            @pgf(PlotInc(
                Coordinates(x, y),     
            )),
            @pgf(LegendEntry("$formulation")),
        ])
    end

    plt = TikzDocument()
    push!(plt, hasymptote())
    symbolic_coords = ratio_string.(ratios)

    axs = @pgf Axis(
        {
            ybar,
            enlarge_x_limits=0.10,
            bar_width = "8pt",
            width = "10cm",
            height = "5cm",
            legend_style =
            {
                 at = Coordinate(0.95, 1.15),
                 anchor = "north east",
                 legend_columns = -1
            },
            ymin=0,
            symbolic_x_coords = symbolic_coords,
            nodes_near_coords_align={vertical},
            ymajorgrids,
            ylabel_style={
                align = "center",
            },
            xtick="data",
            ytick = 1:(ceil(Int, pmm_performance / dram_performance)),
            ymax = ceil(Int, pmm_performance / dram_performance),
            # Lables
            xlabel = "PMM to DRAM Ratio",
            ylabel = "Speedup over all PMM",

        },
        plots...,
        # Draw a horizontal line at the DRAM performance
        #HLine(pmm_performance / get_dram_performance(data)),
        hline(pmm_performance / get_dram_performance(data);
              xl = first(symbolic_coords),
              xu = last(symbolic_coords)
             ),
        raw"\addlegendimage{line legend, black, sharp plot, thick}",
        LegendEntry("All DRAM"),
    )

    push!(plt, TikzPicture(axs))

    pgfsave(file, plt)
    return nothing
end


"""
`pairs`: Vector of Pairs, first element is a model, second element is a formulation string.
"""
function pgf_cost(pairs::Vector{<:Pair}, ratios::Vector{<:Rational}; 
        cost_ratio = 2.5,
        file = "plot.tex", 
    )

    plots = [] 
    for (f, formulation) in pairs
        data = load_save_files(f, formulation)
        dram_performance = get_dram_performance(data)

        # This x and y data point
        x = []
        y = []

        for ratio in ratios
            ind = findabsmin(x -> compare_ratio(getratio(x), ratio), data.runs)
            perf = dram_performance / data.runs[ind][:actual_runtime]

            push!(x, ratio_string(ratio))
            push!(y, perf)
        end

        # Emit the plot for this series.
        append!(plots, [
            @pgf(PlotInc(
                Coordinates(x, y),     
            )),
            @pgf(LegendEntry(replace(titlename(f), "_" => " "))),
        ])
    end

    plt = TikzDocument()
    push!(plt, """
    \\pgfplotsset{width=7cm,height=4cm}
    """)


    symbolic_coords = ratio_string.(ratios)

    # Bar axis
    tikz = TikzPicture() 
    axs = @pgf Axis(
        {
            "axis_y_line*=left",
            "scale_only_axis",
            ybar,
            bar_width = "8pt",
            legend_style =
            {
                 at = Coordinate(0.4, 1.15),
                 anchor = "north",
                 legend_columns = -1
            },
            ymin = 0,
            ymax = 1,
            symbolic_x_coords = symbolic_coords,
            nodes_near_coords_align={vertical},
            ymajorgrids,
            ylabel_style={
                align = "center",
            },
            xtick="data",
            #ytick = [0,1],
            # Lables
            xlabel = "PMM to DRAM Ratio",
            ylabel = "Performance Relative to all DRAM",

        },
        plots...,
    )
    push!(tikz, axs)

    # Cost Axis
    y_cost = map(ratios) do ratio
        # PMM
        num = ratio.num

        # DRAM
        den = ratio.den

        # Total approximately sums to 1
        return (num / cost_ratio + den) / (num + den)
    end

    axs = @pgf Axis(
        {
            "axis_y_line*=right",
            "scale_only_axis",
            axis_x_line = "none",
            only_marks,
            ymin = 0,
            ymax = 1,
            symbolic_x_coords = symbolic_coords,
            ylabel = "Memory cost relative to all DRAM"
        },
        PlotInc(
            Coordinates(symbolic_coords, y_cost),
        ),
    )
    push!(tikz, axs)
    push!(plt, tikz)

    pgfsave(file, plt)
    return nothing
end
