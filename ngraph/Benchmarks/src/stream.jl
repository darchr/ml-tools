#####
##### STREAM benchmark
#####

struct STREAM end

function compile(::Type{STREAM};
        array_size = 1000000,
        use_mmap = false,
    )

    args = [
        "-march=native",
        "-mtune=native",
        "-mcmodel=large",
        "-DSTREAM_ARRAY_SIZE=$array_size",
        "-O3",
        "-fopenmp",
    ]
    if use_mmap
        push!(args, "-DUSE_MMAP")
    end

    run(`g++ $args $CPP_FILE -o $CPP_EXE -lpmem`)
    return nothing
end

function Base.run(::Type{STREAM}; 
        cpu_info = CPUInfo(),
        cpu_node = 1,
        num_threads = 24,
        mem_node = 1,
        mmap_file = nothing
    )   

    # Convert the number of CPUS to a string for numactl
    base = cpu_node * cpu_info.cpus_per_socket

    # If the number of requested CPUs is less than the number of CPUs per socket, we're good.
    # NOTE: This current implementation only works up to a maximum of 2 threads
    if num_threads <=  cpu_info.cpus_per_socket
        physcpu = "$base-$(base+num_threads-1)"
    else
        # Otherwise, build up a base using the first CPUs on each thread, then tack on the
        # rest
        physcpu_base = "$base-$(base + cpu_info.cpus_per_socket - 1)"
        remaining = num_threads - cpu_info.cpus_per_socket

        base = (cpu_node + cpu_info.nsockets) * cpu_info.cpus_per_socket
        physcpu = "$physcpu_base,$base-$(base + remaining - 1)"
    end
    @show physcpu

    args = [
        "--physcpubind=$physcpu",
        "--membind=$mem_node",
        CPP_EXE,
    ]
    !isnothing(mmap_file) && push!(args, mmap_file)

    return read(`numactl $args`, String)
end

#####
##### Code for running the benchmarks
#####

function benchmark(::Type{STREAM}; 
        mmap_file = "/mnt/public/file.pmem", 
        max_threads = 24,
        array_size = 100000000
    )
    # Benchmark from 1 to 24 threads both with MMap and without MMap

    dram_data = NamedTuple[]
    for num_threads in 1:max_threads
        compile(STREAM; array_size = array_size, use_mmap = false)
        str = run(STREAM; num_threads = num_threads)
        push!(dram_data, _parse(STREAM, str, num_threads))
    end

    # Create the file for mmaping 
    ispath(mmap_file) && rm(mmap_file)
    touch(mmap_file)

    # Compile and run once to allocate data in the file
    compile(STREAM; array_size = array_size, use_mmap = true) 
    run(STREAM; num_threads = max_threads, mmap_file = mmap_file)

    pmm_data = NamedTuple[]
    for num_threads in 1:max_threads
        compile(STREAM; array_size = array_size, use_mmap = true)
        str = run(STREAM; num_threads = num_threads, mmap_file = mmap_file)
        push!(pmm_data, _parse(STREAM, str, num_threads))
    end

    return dram_data, pmm_data
end

function _parse(::Type{STREAM}, str, nthreads)
    # Read until we see that "DATA" tag
    lines = split(str, "\n") 
    line_number = findfirst(x -> startswith(x, "DATA"), lines)
    # Increment by 2 to get to the first data line
    line_number += 2  

    # Start parsing
    data_tuple = ntuple(6) do _
        line = lines[line_number]
        data = parse(Float64, split(line)[2])
        line_number += 1
        return data
    end

    syms = (
        :nthreads,
        :stream_to_remote, 
        :stream_to_local, 
        :copy_to_remote, 
        :copy_to_local, 
        :read, 
        :write
    )

    return NamedTuple{syms}((nthreads, data_tuple...))
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
            # Put the lagen outside on the right
            legend_style = 
            {
                 at = Coordinate(1.1, 0.5),
                 anchor = "west",
            },
            legend_cell_align = "left",
        },
        # Try to put these in the order they appear
        PlotInc(Coordinates(_coordinates(dram_data, :read))),
        LegendEntry("DRAM Read"),
        PlotInc(Coordinates(_coordinates(dram_data, :write))),
        LegendEntry("DRAM Write"),
        PlotInc(Coordinates(_coordinates(dram_data, :copy_to_local))),
        LegendEntry(raw"DRAM $\rightarrow$ DRAM"),
        PlotInc(Coordinates(_coordinates(dram_data, :stream_to_local))),
        LegendEntry(raw"DRAM $\rightarrow$ DRAM (stream)"),

        PlotInc(Coordinates(_coordinates(pmm_data, :read))),
        LegendEntry("PMM Read"),
        PlotInc(Coordinates(_coordinates(pmm_data, :stream_to_local))),
        LegendEntry(raw"PMM $\rightarrow$ DRAM (stream)"),
        PlotInc(Coordinates(_coordinates(pmm_data, :copy_to_local))),
        LegendEntry(raw"PMM $\rightarrow$ DRAM"),

        PlotInc(Coordinates(_coordinates(pmm_data, :write))),
        LegendEntry("PMM Write"),
        PlotInc(Coordinates(_coordinates(pmm_data, :stream_to_remote))),
        LegendEntry(raw"DRAM $\rightarrow$ PMM (stream)"),
        PlotInc(Coordinates(_coordinates(pmm_data, :copy_to_remote))),
        LegendEntry(raw"DRAM $\rightarrow$ PMM"),
    )

    push!(PGFPlotsX.CUSTOM_PREAMBLE, "\\usepackage{amsmath}")
    pgfsave(file, plt; include_preamble = preamble)
    pop!(PGFPlotsX.CUSTOM_PREAMBLE)
    return nothing
end
