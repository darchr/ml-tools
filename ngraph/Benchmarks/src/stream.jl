#####
##### STREAM benchmark
#####

struct STREAM end

function parse_data(::Type{STREAM})
    data_file = joinpath(DEPSDIR, "stream_data.txt")
    lines = eachline(data_file)

    max_threads = 24

    dram_data = NamedTuple[]
    # Parse entries in the file
    while length(dram_data) < max_threads
        parse_entry!(dram_data, lines)
    end

    # Skip over the next entry
    parse_entry!([], lines)
    pmm_data = NamedTuple[]
    while length(pmm_data) < max_threads
        parse_entry!(pmm_data, lines)
    end

    return dram_data, pmm_data
end

function parse_entry!(data, lines)
    # Spin until we see the "DATA" tag
    local nthreads
    for ln in lines
        if startswith(ln, "Number of Threads counted")
            nthreads = parse(Int, split(ln)[end])
        end
        startswith(ln, "DATA") && break
    end

    # Increment two lines
    for (i, ln) in enumerate(lines)
        i == 1 && break
    end

    # Start parsing
    bw = Float64[]
    for (i, ln) in enumerate(lines)
        @show ln
        push!(bw, parse(Float64, split(ln)[2]))
        i == 4 && break
    end

    syms = (
        :nthreads,
        :stream_to_remote,
        :stream_to_local,
        :read,
        :write
    )

    push!(data, NamedTuple{syms}((nthreads, bw...)))
end

#####
##### Plotting
#####

_coordinates(vec::Vector{<:NamedTuple}, sym) = [(x.nthreads, x[sym] / 1E3) for x in vec]
function gen_plot(::Type{STREAM}, dram_data, pmm_data; file = "plot.tex", preamble = true)
    # Make sure the data is sorted by number of threads
    sort!(dram_data; by = x -> x.nthreads)
    sort!(pmm_data; by = x -> x.nthreads)

    @show _coordinates(dram_data, :read)

    # Step 1: Try to plot everything on a single graph
    plt = @pgf Axis(
        {
            grid = "major",
            ylabel = "Bandwidth GB/s",
            xlabel = "Number of Threads",
            mark_size = "2.5pt",
            # Put the lagen outside on the right
            legend_style =
            {
                 at = Coordinate(1.1, 0.5),
                 anchor = "west",
            },
            legend_cell_align = "left",
        },
        # Try to put these in the order they appear
        PlotInc(
            {
                "blue",
                mark="*",
                mark_options = {
                    fill = "blue",
                },
            },
            Coordinates(_coordinates(dram_data, :read))
        ),
        LegendEntry("DRAM Read"),

        PlotInc(
            {
                "blue",
                mark="square*",
                mark_options = {
                    fill = "blue",
                },
            },
            Coordinates(_coordinates(dram_data, :write))
        ),
        LegendEntry("DRAM Write"),

        PlotInc(
            {
                "red",
                mark="*",
                mark_options = {
                    fill = "red",
                },
            },
            Coordinates(_coordinates(pmm_data, :read))
        ),
        LegendEntry("PMM Read"),

        PlotInc(
            {
                "red",
                mark="square*",
                mark_options = {
                    fill = "red",
                },
            },
            Coordinates(_coordinates(pmm_data, :write))
        ),
        LegendEntry("PMM Write"),

        PlotInc(
            {
                "solid",
                "black",
                mark="triangle",
                mark_options = {
                    fill = "black",
                },
            },
            Coordinates(_coordinates(pmm_data, :stream_to_local))
        ),
        LegendEntry(raw"PMM $\rightarrow$ DRAM"),

        PlotInc(
            {
                "solid",
                "black",
                mark="triangle*",
                mark_options = {
                    fill = "black",
                },
            },
            Coordinates(_coordinates(pmm_data, :stream_to_remote))
        ),
        LegendEntry(raw"DRAM $\rightarrow$ PMM"),
    )

    push!(PGFPlotsX.CUSTOM_PREAMBLE, "\\usepackage{amsmath}")
    pgfsave(file, plt; include_preamble = preamble)
    pop!(PGFPlotsX.CUSTOM_PREAMBLE)
    return nothing
end
