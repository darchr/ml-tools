module Benchmarks

export STREAM

# Pathing schenanigans
const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")
const STREAMDIR = joinpath(DEPSDIR, "STREAM")

const CPP_FILE = joinpath(STREAMDIR, "cpp", "stream.cpp")
const CPP_EXE = joinpath(STREAMDIR, "cpp", "stream")

#####
##### CPU Info
#####

struct CPUInfo
    nsockets::Int
    cpus_per_socket::Int
    hyperthreaded::Bool
end

# Default to the Intel machines we're working on
CPUInfo() = CPUInfo(2, 24, true)

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

    run(`g++ $args $CPP_FILE -o $CPP_EXE`)
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

    run(`numactl $args`)
end

end # module
