# ML-Tools

Collection of tools for analyzing machine learning workloads.

## Docker API Interface
Right now, I think the running of experiments and workloads will take place in Docker 
containers for reproducibility and sandboxing. This approach will be revisited in the future
if it turns out not to work super well for some reason.

Docker has a nice `http` based interface for launching, controlling, and cleaning containers.
I wrote a Julia tool: <https://github.com/hildebrandmw/DockerX.jl> (still a WIP, will be 
extended as needed) to interface with this API. Hopefully, this will help with 
programatically running experiments.

## wss

Tool written by Brendan Gregg for estimating the working set size of an application.
The idea here is to get an idea of the working set size of ML workloads.

<http://www.brendangregg.com/wss.html>
<https://github.com/brendangregg/wss>

## Directories created on `amarillo`

Below is (hopefully) a comprehensive list of directories created on `amarillo` during
this project. The goal of this list is to aid in cleaning up after maintainance.

* `/data1/ml-datasets` - Datasets for machine learning algorithms.
