#####
##### Plots for GPU code
#####

function pgf_gpu_performance_plot(
        funcs;
        file = "plot.tex",
        formulations = ("synchronous", "asynchronous")
    )


    bar_plots = []
    memory_plots = []
    annotations = []

    coords = []

    # First step, compute the managed runtime performance for each function as a baseline
    baseline_runtime = Dict{Any,Float64}()
    for (i, f) in enumerate(funcs)
        for formulation in formulations
            datum = load_save_files(f, formulation)
            baseline_runtime[f] = min(
                get(baseline_runtime, f, typemax(Float64)),
                datum.gpu_managed_runtime[]
            )
        end
        push!(annotations, @pgf([
            raw"\node at ",
            Coordinate(i, -0.75),
            "{$(f.batchsize)};"
        ]))
    end

    # Generate function labels
    for title in unique(titlename.(funcs))
        # Get the start and stop indices for this title
        start = findfirst(x -> titlename(x) == title, funcs)
        stop = findlast(x -> titlename(x) == title, funcs)
        center = (start + stop) / 2

        push!(annotations, @pgf([
            raw"\node at ",
            Coordinate(center, -1.5),
            "{$title};",
        ]))
    end

    # Generate data for the formulations
    for formulation in formulations
        y = []
        x = []

        for (i, f) in enumerate(funcs)
            datum = load_save_files(f, formulation)

            speedup = baseline_runtime[f] / minimum(getname(datum.runs, :actual_runtime))

            push!(x, i)
            push!(y, speedup)

        end
        append!(bar_plots, [
            @pgf(PlotInc(
                Coordinates(x, y),
            ))
            @pgf(LegendEntry(formulation))
        ])
    end

    # Finally, plot the ideal implmenetation
    x = []
    y = []
    for (i, f) in enumerate(funcs)
        data = load_save_files(f, formulations)

        # Conovert milliseconds to seconds
        ideal = minimum(minimum.(getname.(getname(data, :runs), :oracle_time))) / 1E6
        @show ideal

        push!(x, i)
        push!(y, baseline_runtime[f] / ideal)
    end

    append!(bar_plots, [
        @pgf(PlotInc(
            Coordinates(x, y),
        ))
        @pgf(LegendEntry("oracle"))
    ])

    # Generate the lefthand bar plot
    plt = TikzDocument()
    push!(plt, """
    \\pgfplotsset{
        width=10cm,
        height=4cm
    }
    """)

    tikz = TikzPicture()

    push!(tikz, """
        \\pgfplotsset{set layers}
        """)
    axs = @pgf Axis(
        {
            "scale_only_axis",
            "axis_y_line*=left",
            ybar,
            xmin = 0.5,
            xmax = length(funcs) + 0.5,
            xmajorticks = "false",
            bar_width = "5pt",
            clip = "false",
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

            # Lables
            ylabel = "Speedup over\\\\CudaMallocManaged",
        },
        bar_plots...,
        annotations...,
    )
    push!(tikz, axs)

    # Generate the righthand memory usage plots

    # Begin generating marker dots for the memory usage
    x = []
    gpu_y = []
    cpu_y = []

    # To shift the dots around to they line up with their corresponding bars, we need
    # an initial "x" offset as well as an "x" shift.
    #
    # I don't really have a good way of auto generating this, so we're going to go with the
    # "play with numbers until it looks right" approach.
    x_offset = -0.28
    x_step = 0.28

    for (i, f) in enumerate(funcs)
        for (j, formulation) in enumerate(formulations)
            datum = load_save_files(f, formulation)

            # Plot the GPU Dram as a circle
            push!(x, i + x_offset + (j-1) * x_step)
            push!(gpu_y, minimum(getname(datum.runs, :dram_alloc_size)) / 1E9)

            # Plot the Host DRAM
            push!(cpu_y, minimum(getname(datum.runs, :pmem_alloc_size)) / 1E9)
        end
    end
    axs = @pgf Axis(
        {
            "scale_only_axis",
            "axis_y_line*=right",
            axis_x_line = "none",
            legend_style =
            {
                 at = Coordinate(0.95, 1.05),
                 anchor = "south",
                 legend_columns = -1
            },
            only_marks,
            ymin = 0,
            #ymax = 64,
            xmin = 0.5,
            xmax = length(funcs) + 0.5,
            ylabel = "Memory Pool Size (GB)",
        },
        PlotInc(Coordinates(x, gpu_y)),
        LegendEntry("GPU DRAM"),
        PlotInc(Coordinates(x, cpu_y)),
        LegendEntry("CPU DRAM"),
    )

    push!(tikz, axs)

    push!(plt, tikz)

    pgfsave(file, plt)
    return nothing
end
