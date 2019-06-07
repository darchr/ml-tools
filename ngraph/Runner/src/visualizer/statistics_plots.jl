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

