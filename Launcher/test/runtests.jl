using Launcher
using Test
using Docker

const ROOT = joinpath(@__DIR__, "..", "..")
const WORKLOADS = joinpath(ROOT, "workloads")

# Pull the needed images
@info "Pulling Needed Docker Images"
Docker.pull_image("ubuntu:latest")
Docker.pull_image("darchr/tf-compiled-base:latest")

include("utils.jl")
# Remove since I moved everything to a single docker container
#include("docker.jl")
include("workloads.jl")
