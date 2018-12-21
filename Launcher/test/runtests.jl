using Launcher
using Test
using DockerX

const ROOT = joinpath(@__DIR__, "..", "..")
const DOCKER = joinpath(ROOT, "docker")

# Pull the needed images
@info "Pulling Needed Docker Images"
DockerX.pull_image("ubuntu:latest")
DockerX.pull_image("darchr/tf-compiled-base:latest")

include("utils.jl")
# Remove since I moved everything to a single docker container
#include("docker.jl")
include("workloads.jl")
