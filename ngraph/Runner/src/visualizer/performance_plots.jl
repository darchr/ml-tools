# The function naming here is closely tied to the naming schemes outlined in top.jl
#
# If I was really thinking ahead, I'd think of a way to do name detection automatically...
using Plots.PlotMeasures

struct PerformancePlot end
@enum __PerformancePlotStyle __NO_PLOT __ACTUAL_PLOT __PREDICTED_PLOT
@recipe function f(::PerformancePlot, f; 
        static          = __ACTUAL_PLOT, 
        synchronous     = __ACTUAL_PLOT, 
        asynchronous    = __NO_PLOT
    )

    nt = (static = static, synchronous = synchronous, asynchronous = asynchronous)
    markers = (static = :square, synchronous = :circle, asynchronous = :x)

    # Setup some global figure definitions
    seriestype := :line
    fmt := :png
    title := titlecase(replace(name(f), "_" => " "))
    linewidth := 3
    markersize := 8
    xlabel := "DRAM Limit (GB)"
    ylabel := "Slowdown relative to all DRAM"
    size := (500, 500)
    bottom_margin := 5mm
    left_margin := 10mm

    font = Plots.font("Helvetica", 10)
    xtickfont := font
    ytickfont := font
    legendfont := font

    # Determine the data structures to load
    #
    # This isn't necessarily the prettiest way to do this - but it will work and has decent
    # code reuse.
    for formulation in (:static, :synchronous, :asynchronous) 
        # Get the plot type and skip things non-plotted items.
        plot_type = nt[formulation]
        plot_type == __NO_PLOT && continue
         
        # Deserialize the data structure.
        if plot_type == __PREDICTED_PLOT 
            savefile = joinpath(savedir(f), join((name(f), formulation, "estimate"), "_") * ".jls")
        else
            savefile = joinpath(savedir(f), join((name(f), formulation), "_") * ".jls")
        end
        data = deserialize(savefile)

        io_size = data.io_size[]

        # If using predicted runtimes - correct for microsecond to second conversion.
        runtimes = plot_type == __ACTUAL_PLOT ? 
            (getindex.(data.runs, :actual_runtime)) : 
            (getindex.(data.runs, :predicted_runtime) ./ 1E6)

        @show runtimes

        dram_performance = first(runtimes)

        dram_sizes = plot_type == __ACTUAL_PLOT ?
            ((getindex.(data.runs, :dram_alloc_size) .+ io_size) ./ 1E9) :
            ((getindex.(data.runs, :dram_limit) ./ 1E3) .+ (io_size ./ 1E9))

        # Attributes
        marker := markers[formulation]

        @series begin
            # Construct x and y
            x = dram_sizes
            y = runtimes ./ dram_performance

            # Construct Label
            lab = titlecase(string(formulation))
            plot_type == __PREDICTED_PLOT && (lab = join((lab, "(Predicted)"), " "))
            lab := lab

            x, y
        end
    end
end

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
