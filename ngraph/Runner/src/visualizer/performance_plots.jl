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

function pgf_large_performance(fns; 
        file = "plot.tex", 
        formulations = ("static", "synchronous")
    )
    # Step through each function, get the 2lm performance
    bar_plots = []
    coords = String[]

    baseline_runtime = Dict{Any,Float64}()
    for f in fns
        baseline = load_save_files(f, "2lm")
        baseline_runtime[f] = minimum(getname(baseline.runs, :actual_runtime))

        push!(coords, "$(titlename(f)) ($(f.batchsize))")
    end

    for formulation in formulations
        x = []
        y = []

        for (i, f) in enumerate(fns)
            datum = load_save_files(f, formulation)
            speedup = baseline_runtime[f] / minimum(getname(datum.runs, :actual_runtime))
            push!(x, "$(titlename(f)) ($(f.batchsize))")
            push!(y, speedup)
        end

        append!(bar_plots, [
            @pgf(PlotInc(
                Coordinates(x, y),
            ))
            @pgf(LegendEntry(formulation))
        ])
    end

    plt = TikzDocument()
    push!(plt, """
    \\pgfplotsset{width=7cm,height=4cm}
    """)

    # Bar axis
    tikz = TikzPicture() 
    axs = @pgf Axis(
        {
            ybar,
            bar_width = "20pt",
            enlarge_x_limits=0.30,
            symbolic_x_coords = coords,
            #nodes_near_coords_align={vertical},

            legend_style =
            {
                 at = Coordinate(0.05, 1.05),
                 anchor = "south west",
                 legend_columns = -1
            },
            ymin=0,
            ymajorgrids,
            ylabel_style={
                align = "center",
            },
            xticklabel_style={
                rotate = 15,
            },
            xtick = "data",

            # Lables
            ylabel = "Speedup over 2LM",
        },
        bar_plots...,
    )
    push!(tikz, axs)
    push!(plt, tikz)

    pgfsave(file, plt)
    return nothing
end
