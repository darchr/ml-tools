using Launcher
using Test

const ROOT = joinpath(@__DIR__, "..", "..")
const DOCKER = joinpath(ROOT, "docker")

include("utils.jl")
include("docker.jl")
include("workloads.jl")
