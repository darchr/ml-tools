@enum __PerformancePlotStyle __NO_PLOT __ACTUAL_PLOT __PREDICTED_PLOT
function pgf_plot_performance(f;
        static = __ACTUAL_PLOT,
        synchronous = __ACTUAL_PLOT,
        asynchronous = __NO_PLOT,
        file = "plot.tex",
    )

    nt = (static = static, synchronous = synchronous, asynchronous = asynchronous)

    coords = []
    formulations = (:static, :synchronous, :asynchronous)
    # First, find the dram performance
    dram_performance = typemax(Float64)
    for formulation in formulations
        plot_type = nt[formulation]
        plot_type == __NO_PLOT && continue

        # Deserialize the data structure.
        if plot_type == __PREDICTED_PLOT
            savefile = joinpath(savedir(f), join((name(f), formulation, "estimate"), "_") * ".jls")
        else
            savefile = joinpath(savedir(f), join((name(f), formulation), "_") * ".jls")
        end
        data = deserialize(savefile)
        sort!(data.runs; rev = true, by = x -> x[:dram_limit])

        # If using predicted runtimes - correct for microsecond to second conversion.
        runtimes = plot_type == __ACTUAL_PLOT ?
            (getindex.(data.runs, :actual_runtime)) :
            (getindex.(data.runs, :predicted_runtime) ./ 1E6)

        dram_performance = min(dram_performance, first(runtimes))
    end

    for formulation in formulations
        plot_type = nt[formulation]
        plot_type == __NO_PLOT && continue

        # Deserialize the data structure.
        if plot_type == __PREDICTED_PLOT
            savefile = joinpath(savedir(f), join((name(f), formulation, "estimate"), "_") * ".jls")
        else
            savefile = joinpath(savedir(f), join((name(f), formulation), "_") * ".jls")
        end
        data = deserialize(savefile)
        sort!(data.runs; rev = true, by = x -> x[:dram_limit])

        io_size = data.io_size[]

        # If using predicted runtimes - correct for microsecond to second conversion.
        runtimes = plot_type == __ACTUAL_PLOT ?
            (getindex.(data.runs, :actual_runtime)) :
            (getindex.(data.runs, :predicted_runtime) ./ 1E6)

        dram_sizes = (getindex.(data.runs, :dram_limit) ./ 1E3) .+ (io_size ./ 1E9)

        # Create x and y coordinate, generate pairs
        x = dram_sizes
        y = runtimes ./ dram_performance

        push!(coords, Coordinates(x, y))
    end

    plots = Plot.(coords)
    legend = collect(string.(formulations))

    plt = @pgf Axis(
        {
            grid = "major",
            ylabel = "Normalized Runtimes",
            xlabel = "Dram Limit (GB)",
        },
        Plot(
            {
                thick,
                color = "blue",
                mark = "square*"
            },
            coords[1],
        ),
        Plot(
            {
                thick,
                color = "red",
                mark = "*"
            },
            coords[2],
        ),
        # Plot(
        #     {
        #         thick,
        #         color = "black",
        #         mark = "triangle*"
        #     },
        #     coords[3],
        # ),
        Legend(legend),
    )

    pgfsave(file, plt)
    return nothing
end

#function pgf_numa_plot(f; file = "plot.tex", formulations = ("static", "synchronous"))
#    data = _load_save_files(f, formulations)
#    dram_performance = get_dram_performance(data)
#
#    numa_data = deserialize(
#        joinpath(savedir(f), join((name(f), "numa"), "_") * ".jls")
#    )
#
#    numa_limits = getname(numa_data, :dram_limit)
#    numa_runtimes = getname(numa_data, :actual_runtime)  
#
#    plots = []
#    for (d, formulation) in zip(data, formulations)
#        x = [] 
#        y = []
#        for (numa_limit, numa_runtime) in zip(numa_limits, numa_runtimes)
#            # Find the entry in `d` that has the closest limit to this numa amount
#
#            dram_limits = getname(d.runs, :dram_limit)
#            __temp = abs.(dram_limits .- numa_limit ./ 1E6)
#            _, ind = findmin(__temp)
#            perf = getname(d.runs, :actual_runtime)[ind]
#
#            push!(x, round(Int, numa_limit ./ 1E9))
#            push!(y, numa_runtime / perf)
#
#        end
#        append!(plots, [
#        @pgf(PlotInc(
#             Coordinates(
#                x, y  
#            ),
#        ))
#        @pgf(LegendEntry("$formulation"))
#        ])
#    end
#
#    # Get the numa DRAM values in GB
#    coords = round.(Int, numa_limits ./ 1E9)
#
#    plt = @pgf Axis(
#        {
#            ybar,
#            enlarge_x_limits=0.20,
#            legend_style =
#            {
#                 at = Coordinate(0.95, 0.95),
#                 anchor = "north east",
#                 legend_columns = -1
#            },
#            ymin=0,
#            symbolic_x_coords=coords,
#            nodes_near_coords_align={vertical},
#            ymajorgrids,
#            ylabel_style={
#                align = "center",
#            },
#            xtick="data",
#            bar_width="20pt",
#            # Lables
#            xlabel = "DRAM Size (GB)",
#            ylabel = "Relative Performance to\\\\first touch NUMA",
#        },
#        plots...
#    )
#
#    pgfsave(file, plt)
#    return nothing
#end
