# Code for managing the building of Docker constainers and stuff
const DOCKERDIR = joinpath(MLTOOLS, "docker")

abstract type AbstractDockerImage end
dependencies(::AbstractDockerImage) = ()

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

# Overload "create" so we can automatically build containers when a workload is launched
# if it doesn't exist.
function create_container(image::AbstractDockerImage; kw...)
    instantiate(image)
    return create_container(tag(image); kw...)
end

# Add "SYS_PTRACE" to all containers launched from here to support snooping them with vtune.
create_container(image::AbstractString; kw...) = 
    Docker.create_container(image; capadd = ["SYS_PTRACE"], kw...)

#####
##### TensorflowBuilder
#####

"""
Docker image for Tensorflow compiled with MKL
"""
struct TensorflowMKL <: AbstractDockerImage end

tag(::TensorflowMKL) = "darchr/tensorflow-mkl:latest"

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

        wheel = basename(first(wheels))
        run(`./build-image.sh ./$wheel`)
    finally
        cd(dir)
    end
end

#####
##### GNMT
#####

"""
PyTorch docker container for the [`Launcher.Translator`](@ref) workload.
"""
struct GNMT <: AbstractDockerImage end

tag(::GNMT) = "darchr/gnmt:latest"

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

"""
Intermediate image with a compiled version of the ANTs image processing library.
"""
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

"""
Image containing the dependencies for the 3d Unet workload
"""
struct Unet3d <: AbstractDockerImage end

tag(::Unet3d) = "darchr/3dunet:latest"
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

#####
##### nGraph
#####

struct NGraphImage <: AbstractDockerImage end
tag(::NGraphImage) = "darchr/ngraph:latest"

function build(::NGraphImage)
    @info "Building nGraph Image"
    dir = pwd()
    try
        cd(joinpath(DOCKERDIR, "ngraph-exp"))
        run(`./build.sh`)
    finally
        cd(dir)
    end
end

##### 
##### Tensorflow VTune
#####

struct TensorflowVTune <: AbstractDockerImage
    args::NamedTuple
    outfile::String
end

tag(::TensorflowVTune) = "darchr/tensorflow-vtune:latest"
dependencies(::TensorflowVTune) = (TensorflowMKL(),)

function build(::TensorflowVTune)
    @info "Building Tensorflow VTune Image"
    dir = pwd()
    try
        cd(joinpath(DOCKERDIR, "tensorflow-vtune"))
        vtunes = glob(glob"*.tar.gz", pwd())
        run(`./build-image.sh $(first(vtunes))`)
    finally
        cd(dir)
    end
end
