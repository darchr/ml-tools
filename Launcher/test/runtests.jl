using Launcher
using Test

const ROOT = joinpath(@__DIR__, "..", "..")
const DOCKER = joinpath(ROOT, "docker")

include("utils.jl")
# Remove since I moved everything to a single docker container
#include("docker.jl")
include("workloads.jl")
