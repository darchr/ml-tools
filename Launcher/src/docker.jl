# Code for managing the building of Docker constainers and stuff
const DOCKERDIR = joinpath(MLTOOLS, "docker")

abstract type AbstractDockerImage end

function hasimage(::T) where {T <: AbstractDockerImage}
    # Get all of the images on the system
    allimages = getindex.(Docker.list_images(), "RepoTags")
    return any(x -> in(image(T), x), allimages)
end

#####
##### TensorflowBuilder
#####

struct TensorflowMKL <: AbstractDockerImage end

image(::TensorflowMKL) = "darchr/tensorflow-mkl:latest"
dependencies(::TensorflowMKL) = ()

function build(::TensorflowMKL)
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

image(::GNMT) = "darchr/gnmt:latest"
dependencies(::GNMT) = ()

function build(::GNMT)
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

image(::ANTS) = "darchr/ants:latest"
dependencies(::ANTS) = (TensorflowMKL,)

function build(::ANTS)
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

image(::Unet3d) = "darchr/unet3d:latest"
dependencies(::Unet3d) = (ANTS,)

function build(::ANTS)
    dir = pwd()
    try
        cd(joinpath(DOCKERDIR, "unet3d"))
        run(`./build.sh`)
    finally
        cd(dir)
    end
end
