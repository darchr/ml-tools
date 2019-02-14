# ML-Tools

This repo contains a collection of tools, containers, and scripts for launching
machine learning workloads in Docker containers and collecting statistics about the 
containers.

## Installation and Setup

While this repo is set up to provide the various workloads and Docker images as standalone
entities, the `Launcher` module provides a more unified way of controlling the launching
of Docker containers for the various workloads and gathering statistics (as well as building
the docker images if they don't exist yet on your system). To use `Launcher`, you will need
[Julia](https://julialang.org) 1.1.0 installed on your system.

### Installing Julia

If your are running on Linux, you can install Julia 1.1.0 with the commands below:
```
cd ~
wget https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1.0-linux-x86_64.tar.gz
tar -xvf julia-1.1.0-linux-x86_64.tar.gz
rm julia-1.1.0-linux-x86_64.tar.gz
```
You can then type
```
~/julia-1.1.0/bin/julia
```
to launch Julia. If you don't like typing that whole path, then placing the line
```
alias julia=~/julia-1.1.0/bin/julia
```
in your `.bash_aliases` file and running `source ~/.bashrc` will let you just type `julia`
to launch the program.

### Installing ML-Tools

Clone the repo with
```
git clone https://github.com/darchr/ml-tools
cd ml-tools
./init.sh <path/to/julia>
```

### Obtaining Datasets

Obtaining datasets can be an arduous and peril ridden task.  See the relevant page 
regarding your dataset of interest for more information on how to obtain the dataset and
prepare it for use in these workloads. 

If you are a member of the `darchr` group working on Amarillo, chances are the dataset 
already exists in `/data/ml-datasets`.

### Configuring Dataset Paths

Launcher will need to know the paths to relevant datasets in order to corretly link them
into the Docker containers. It uses the file `Launcher/setup.json` to map the locations
of these directories. To create and edit this file, run the following sequence of commands:
```
cd ml-tools/Launcher
julia --project=.

# Inside the Julia REPL
julia> using Launcher

# If you would prefer to use Vim instead of Emacs
julia> ENV["JULIA_EDITOR"] = "vim"

julia> Launcher.edit_setup()
```
Inside the text editor, enter the paths to datasets your are using. Note that it is okay to
leave the paths to datasets you aren't using empty. If you are on amarillo, some relevant
paths are:
```
"cifar": "/data1/ml-datasets/cifar-10-batches-py.tar.gz",
"imagenet_tf_slim": "/data1/ml-datasets/imagenet/slim",
```

Once you save and exit the editor, your changes will be saved and you can run your workloads!

## Building Docker Images

If a docker image for a workload does not exist on your system, it will automatically be
built the first time that workload is run. Not that in some cases (basically all), this will
take quite some time as things need to compile.
