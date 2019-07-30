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

    coords = []

    #symbolic_coords = replace.(name.(funcs), Ref("_" => " "))

    # First step, compute the managed runtime performance for each function as a baseline
    baseline_runtime = Dict{Any,Float64}()
    for f in funcs
        for formulation in formulations
            datum = load_save_files(f, formulation)
            baseline_runtime[f] = min(
                get(baseline_runtime, f, typemax(Float64)),
                datum.gpu_managed_runtime[]
            )
        end
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
        width=7cm,
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
            bar_width = "8pt",
            legend_style =
            {
                 at = Coordinate(0.95, 1.15),
                 anchor = "north east",
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
    )
    push!(tikz, axs)
    push!(plt, tikz)

    pgfsave(file, plt)
    return nothing
end
