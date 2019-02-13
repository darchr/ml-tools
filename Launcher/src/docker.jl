# Code for managing the building of Docker constainers and stuff
const DOCKERDIR = joinpath(MLTOOLS, "docker")

abstract type AbstractDockerImage end

function exists(image::AbstractDockerImage)
    # Get all of the images on the system
    allimages = getindex.(Docker.list_images(), "RepoTags")
    return any(x -> in(tag(image), x), allimages)
end

"""
    instantiate(image::AbstractDockerImage)

Perform all the necessary build steps to build and tag the docker image for `image`.
"""
function instantiate(image::AbstractDockerImage)
    exists(image) && return nothing

    # Do a depth-first building of dependencies
    for dep in dependencies(image)
        instantiate(dep)
    end
    build(image)
    return nothing
end

#####
##### TensorflowBuilder
#####

struct TensorflowMKL <: AbstractDockerImage end

tag(::TensorflowMKL) = "darchr/tensorflow-mkl:latest"
dependencies(::TensorflowMKL) = ()

function build(::TensorflowMKL)
    @info "Building TensorflowMKL"
    # Navigate to the correct directory
    dir = pwd()
    try
        cd(joinpath(DOCKERDIR, "tensorflow-mkl"))
        # Check if the .whl already exists. If not, build it
        wheels = glob(glob"*.whl", pwd())
        if length(wheels) == 0
            @info "Building Tensorflow"
            run(`./build-tensorflow.sh`)
            wheels = glob(glob"*.whl", pwd())
        end

        run(`./build-image.sh $(first(wheels))`)
    finally
        cd(dir)
    end
end

#####
##### GNMT
#####

struct GNMT <: AbstractDockerImage end

tag(::GNMT) = "darchr/gnmt:latest"
dependencies(::GNMT) = ()

function build(::GNMT)
    @info "Building GNMT"
    dir = pwd()
    try
        cd(joinpath(DOCKERDIR, "gnmt"))
        run(`./build.sh`)
    finally
        cd(dir)
    end
end

#####
##### ANTS
#####

struct ANTS <: AbstractDockerImage end

tag(::ANTS) = "darchr/ants:latest"
dependencies(::ANTS) = (TensorflowMKL(),)

function build(::ANTS)
    @info "Building ANTS"
    dir = pwd()
    try
        cd(joinpath(DOCKERDIR, "ants"))
        run(`./build.sh`)
    finally
        cd(dir)
    end
end

#####
##### unet3d
#####

struct Unet3d <: AbstractDockerImage end

tag(::Unet3d) = "darchr/unet3d:latest"
dependencies(::Unet3d) = (ANTS(),)

function build(::Unet3d)
    @info "Building Unet3d"
    dir = pwd()
    try
        cd(joinpath(DOCKERDIR, "unet3d"))
        run(`./build.sh`)
    finally
        cd(dir)
    end
end
