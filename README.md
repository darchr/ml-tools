# ML-Tools

## Tensorflow
We will use [Tensorflow](https://www.tensorflow.org/) as one of the ML frameworks for 
testing. Since the standard distribution for Tensorflow is not compiled with AVX2 
instructions, I compiled Tensorflow from source on `amarillo`. The directory `tf-compile/`
has instructions and tools for how to do this.

The Docker Hub where the most current version of this container lives is
here: <https://hub.docker.com/r/hildebrandmw/tf-compiled-base/>. This repo will be kept 
up-to-date as I make needed changes to the container.

## Docker API Interface
Right now, I think the running of experiments and workloads will take place in Docker 
containers for reproducibility and sandboxing. This approach will be revisited in the future
if it turns out not to work super well for some reason.

Docker has a nice `http` based interface for launching, controlling, and cleaning containers.
I wrote a Julia tool: <https://github.com/hildebrandmw/DockerX.jl> (still a WIP, will be 
extended as needed) to interface with this API. Hopefully, this will help with 
programatically running experiments.

## Directories created on `amarillo`

Below is (hopefully) a comprehensive list of directories created on `amarillo` during
this project. The goal of this list is to aid in cleaning up after maintainance.

* `/data1/ml-datasets` - Datasets for machine learning algorithms.
