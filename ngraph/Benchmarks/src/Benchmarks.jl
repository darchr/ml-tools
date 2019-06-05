module Benchmarks

export STREAM, Kernel

using PGFPlotsX
using Flux, nGraph, Runner

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

include("stream.jl")
include("kernel.jl")

end # module
