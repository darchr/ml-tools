var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#ML-Tools-1",
    "page": "Home",
    "title": "ML-Tools",
    "category": "section",
    "text": "This repo contains a collection of tools, containers, and scripts for launching machine learning workloads in Docker containers and collecting statistics about the  containers."
},

{
    "location": "#Installation-and-Setup-1",
    "page": "Home",
    "title": "Installation and Setup",
    "category": "section",
    "text": "While this repo is set up to provide the various workloads and Docker images as standalone entities, the Launcher module provides a more unified way of controlling the launching of Docker containers for the various workloads and gathering statistics (as well as building the docker images if they don\'t exist yet on your system). To use Launcher, you will need Julia 1.1.0 installed on your system."
},

{
    "location": "#Installing-Julia-1",
    "page": "Home",
    "title": "Installing Julia",
    "category": "section",
    "text": "If your are running on Linux, you can install Julia 1.1.0 with the commands below:cd ~\nwget https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1.0-linux-x86_64.tar.gz\ntar -xvf julia-1.1.0-linux-x86_64.tar.gz\nrm julia-1.1.0-linux-x86_64.tar.gzYou can then type~/julia-1.1.0/bin/juliato launch Julia. If you don\'t like typing that whole path, then placing the linealias julia=~/julia-1.1.0/bin/juliain your .bash_aliases file and running source ~/.bashrc will let you just type julia to launch the program."
},

{
    "location": "#Installing-ML-Tools-1",
    "page": "Home",
    "title": "Installing ML-Tools",
    "category": "section",
    "text": "Clone the repo withgit clone https://github.com/darchr/ml-tools\ncd ml-tools\n./init.sh <path/to/julia>"
},

{
    "location": "#Obtaining-Datasets-1",
    "page": "Home",
    "title": "Obtaining Datasets",
    "category": "section",
    "text": "Obtaining datasets can be an arduous and peril ridden task.  See the relevant page  regarding your dataset of interest for more information on how to obtain the dataset and prepare it for use in these workloads. If you are a member of the darchr group working on Amarillo, chances are the dataset  already exists in /data/ml-datasets."
},

{
    "location": "#Configuring-Dataset-Paths-1",
    "page": "Home",
    "title": "Configuring Dataset Paths",
    "category": "section",
    "text": "Launcher will need to know the paths to relevant datasets in order to corretly link them into the Docker containers. It uses the file Launcher/setup.json to map the locations of these directories. To create and edit this file, run the following sequence of commands:cd ml-tools/Launcher\njulia --project=.\n\n# Inside the Julia REPL\njulia> using Launcher\n\n# If you would prefer to use Vim instead of Emacs\njulia> ENV[\"JULIA_EDITOR\"] = \"vim\"\n\njulia> Launcher.edit_setup()Inside the text editor, enter the paths to datasets your are using. Note that it is okay to leave the paths to datasets you aren\'t using empty. If you are on amarillo, some relevant paths are:\"cifar\": \"/data1/ml-datasets/cifar-10-batches-py.tar.gz\",\n\"imagenet_tf_slim\": \"/data1/ml-datasets/imagenet/slim\",Once you save and exit the editor, your changes will be saved and you can run your workloads!"
},

{
    "location": "#Building-Docker-Images-1",
    "page": "Home",
    "title": "Building Docker Images",
    "category": "section",
    "text": "If a docker image for a workload does not exist on your system, it will automatically be built the first time that workload is run. Not that in some cases (basically all), this will take quite some time as things need to compile."
},

{
    "location": "launcher/launcher/#",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "page",
    "text": ""
},

{
    "location": "launcher/launcher/#Tutorial-1",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "section",
    "text": "Launcher is the Julia package for handling the launching of containers, aggregation of  results, binding containers with relevant datasets, and generally making sure everything is  working correctly. (And if it isn\'t working correctly, please open a GitHub issue :D)"
},

{
    "location": "launcher/launcher/#Basic-Example-1",
    "page": "Tutorial",
    "title": "Basic Example",
    "category": "section",
    "text": "The workloads are all up into individual workloads, each of which has their own documentation. Below is an example of running Resnet 50:cd Launcher\njulia --projectInside the Julia REPL:julia> using Launcher\n\njulia> workload = Slim(args = (model_name = \"resnet_v1_50\", batchsize = 32))\nSlim\n  args: NamedTuple{(:model_name, :batchsize),Tuple{String,Int64}}\n  interactive: Bool false\n\njulia> run(workload)This will create a docker container running Resnet 50 that will keep running until you interrupt it with ctrl + C."
},

{
    "location": "launcher/launcher/#Saving-Output-Log-to-a-File-1",
    "page": "Tutorial",
    "title": "Saving Output Log to a File",
    "category": "section",
    "text": "To run a workload and save the stdout to a file for later analysis, you may pass an open file handle as the log keyword of the run function:julia> using Launcher\n\njulia> workload = Slim(args = (model_name = \"resnet_v1_50\", batchsize = 32))\n\n# Open `log.txt` and pass it to `run`. When `run` exists (via `ctrl + C` or other means),\n# the container\'s stdout will be saved into `log.txt`.\njulia>  open(\"log.txt\"; write = true) do f\n            run(workload; log = f)\n        end"
},

{
    "location": "launcher/launcher/#Running-a-Container-for-X-seconds-1",
    "page": "Tutorial",
    "title": "Running a Container for X seconds",
    "category": "section",
    "text": "The run function optionally accepts an arbitrary function as its first argument, to which it passes a handle to the Docker container is created. This lets you do anything you want with the guarentee that the container will be successfully cleaned up if things go south. If you just want to run the container for a certain period of time, you can do something like the following:julia> using Launcher\n\njulia> workload = Slim(args = (model_name = \"resnet_v1_50\", batchsize = 32))\n\n# Here, we use Julia\'s `do` syntax to implicatly pass a function to the first\n# argument of `run`. In this function, we sleep for 10 seconds before returning. When we\n# return, the function `run` exits.\njulia>  run(workload) do container\n            sleep(10)\n        end"
},

{
    "location": "launcher/launcher/#Gathering-Performance-Metrics-1",
    "page": "Tutorial",
    "title": "Gathering Performance Metrics",
    "category": "section",
    "text": "One way to gather the performance of a workload is to simply time how long it runs for.julia> runtime = @elapsed run(workload)However, for long running workloads like DNN training, this is now always feasible. Another approach is to parse through the container\'s logs and use its self reported times. There are a couple of functions like Launcher.tf_timeparser and  Launcher.translator_parser that provide this functionality for Tensorflow and  PyTorch based workloads respectively. See the docstrings for those functions for what  exactly they return. Example useage is shown below.julia> workload = Launcher.Slim(args = (model_name = \"resnet_v1_50\", batchsize = 32))\n\njulia>  open(\"log.txt\"; write = true) do f\n            run(workload; log = f) do container\n                sleep(120)\n            end\n        end\n\njulia> mean_time_per_step = Launcher.tf_timeparser(\"log.txt\")"
},

{
    "location": "launcher/launcher/#Passing-Commandline-Arguments-1",
    "page": "Tutorial",
    "title": "Passing Commandline Arguments",
    "category": "section",
    "text": "Many workloads expose commandline arguments. These arguments can be passed from launcher using the args keyword argument to the workload constructor, like theargs = (model_name = \"resnet_v1_50\", batchsize = 32)Which will be turned into--model_name=resnet_v1_50 --batchsize=32when the script is invoked. In general, you will not have to worry about whether the result will be turned into --arg==value or --arg value since that is taken care of in the workload implementations. Do note, however, that using both the = syntax and space delimited syntax is not supported.If an argument has a hyphen - in it, such as batch-size, this is encoded in Launcher as a triple underscore ___. Thus, we would encode batch-size=32 asargs = (batch___size = 32,)"
},

{
    "location": "launcher/launcher/#Advanced-Example-1",
    "page": "Tutorial",
    "title": "Advanced Example",
    "category": "section",
    "text": "Below is an advanced example gathering performance counter data for a running workload.# Install packages\njulia> using Launcher, Pkg, Serialization, Dates\n\njulia> Pkg.add(\"https://github.com/hildebrandmw/SystemSnoop.jl\")\n\njulia> using SystemSnoop\n\njulia> workload = Slim(args = (model_name = \"resnet_v1_50\", batchsize = 32))\n\n# Here, we use the SystemSnoop package to provide the monitoring using the `trace` funciton\n# in that package.\njulia>  data = open(\"log.txt\"; write = true) do f \n            # Obtain Samples every Second\n            sampler = SystemSnoop.SmartSample(Second(1))\n\n            # Collect data for 5 minutes\n            iter = SystemSnoop.Timeout(Minute(5))\n\n            # Launch the container. Get the PID of the container to pass to `trace` and then\n            # trace.\n            data = run(workload; log = f) do container\n                # We will measure the memory usage of our process over time.\n                measurements = (\n                    timestamp = SystemSnoop.Timestamp(),\n                    memory = SystemSnoop.Statm(),\n                )\n                return trace(getpid(container), measurements; iter = iter, sampletime = sampler)\n            end\n            return data\n        end\n\n# We can plot the memory usage over time from the resulting data\njulia> Pkg.add(\"UnicodePlots\"); using UnicodePlots\n\njulia> lineplot(getproperty.(data.memory, :resident))\n           ┌────────────────────────────────────────┐\n   2000000 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⡀⡀⠀⠀⠀⠀⠀⠀⠀⣀⡀⢀⣀⣀⡀⣀⣀⣀⡀│\n           │⠀⠀⠀⢰⠊⠉⠉⠉⠉⠉⠁⠈⠈⠁⠀⠀⠉⠉⠁⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀⠉⠉⠉⠀⠉⠈⠁⠈⠉│\n           │⠀⠀⠀⣸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⢠⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⡼⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⡖⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n         0 │⠴⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           └────────────────────────────────────────┘\n           0                                      300\n\n# We can save the `data` datastructure for later using\njulia> serialize(\"my_data.jls\", data)\n\n# Finally, we can analyze the mean time per step\njulia> Launcher.tf_timeparser(\"log.txt\")\n8.042285714285715"
},

{
    "location": "launcher/docstrings/#",
    "page": "Docstrings",
    "title": "Docstrings",
    "category": "page",
    "text": ""
},

{
    "location": "launcher/docstrings/#Launcher.Inception",
    "page": "Docstrings",
    "title": "Launcher.Inception",
    "category": "type",
    "text": "Workload object for the Inception cnn, built using keyword constructors.\n\nFields\n\nargs :: NamedTuple - Arguments to pass to the startup script (see docs).    Default: NamedTuple()\ninteractive :: Bool - If set to true, the container will launch into /bin/bash   instead of Python. Used for debugging the container. Default: false.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.Translator",
    "page": "Docstrings",
    "title": "Launcher.Translator",
    "category": "type",
    "text": "Workload object for the RNN Translator, built using keyword constructors.\n\nFields\n\nargs :: NamedTuple - Arguments to pass to the startup script (see docs).    Default: NamedTuple()\ninteractive :: Bool - If set to true, the container will launch into /bin/bash   instead of Python. Used for debugging the container. Default: false.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.Unet",
    "page": "Docstrings",
    "title": "Launcher.Unet",
    "category": "type",
    "text": "Workload object for the Keras Cifar10 cnn. Built using keyword constructors.\n\nFields\n\nargs :: NamedTuple - Arguments to pass to the startup script (see docs).    Default: NamedTuple()\ninteractive :: Bool - If set to true, the container will launch into /bin/bash   instead of Python. Used for debugging the container. Default: false.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.ANTS",
    "page": "Docstrings",
    "title": "Launcher.ANTS",
    "category": "type",
    "text": "Intermediate image with a compiled version of the ANTs image processing library.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.AbstractWorkload",
    "page": "Docstrings",
    "title": "Launcher.AbstractWorkload",
    "category": "type",
    "text": "Abstract supertype for workloads. Concrete subtypes should be implemented for each workload desired for analysis.\n\nRequired Methods\n\ncreate\ngetargs\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.GNMT",
    "page": "Docstrings",
    "title": "Launcher.GNMT",
    "category": "type",
    "text": "PyTorch docker container for the Launcher.Translator workload.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.TensorflowMKL",
    "page": "Docstrings",
    "title": "Launcher.TensorflowMKL",
    "category": "type",
    "text": "Docker image for Tensorflow compiled with MKL\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.TestWorkload",
    "page": "Docstrings",
    "title": "Launcher.TestWorkload",
    "category": "type",
    "text": "Launch the test workload in a ubuntu image.\n\nFields\n\nnone\n\ncreate Keyword Arguments\n\nnone\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.Unet3d",
    "page": "Docstrings",
    "title": "Launcher.Unet3d",
    "category": "type",
    "text": "Image containing the dependencies for the 3d Unet workload\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Base.Libc.getpid-Tuple{Docker.Container}",
    "page": "Docstrings",
    "title": "Base.Libc.getpid",
    "category": "method",
    "text": "Launcher.getpid(container::Container)\n\nReturn the PID of container.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Base.run-Tuple{Function,Launcher.AbstractWorkload}",
    "page": "Docstrings",
    "title": "Base.run",
    "category": "method",
    "text": "run([f::Function], work::AbstractWorkload; log::IO = devnull, kw...)\n\nCreate and launch a container from work with\n\ncontainer = create(work; kw...)\n\nStart the container and then call f(container). If f is not given, then attach to the container\'s stdout.\n\nThis function ensures that containers are stopped and cleaned up in case something goes wrong.\n\nAfter the container is stopped, write the log to IO\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.bind-Tuple{Any,Any}",
    "page": "Docstrings",
    "title": "Launcher.bind",
    "category": "method",
    "text": "Launcher.bind(a, b) -> String\n\nCreate a docker volume binding string for paths a and b.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.create-Tuple{Launcher.AbstractWorkload}",
    "page": "Docstrings",
    "title": "Launcher.create",
    "category": "method",
    "text": "create(work::AbstractWorkload; kw...) -> Container\n\nCreate a Docker Container for work, with optional keyword arguments. Concrete subtypes of AbstractWorkload must define this method and perform all the necessary steps to creating the Container. Note that the container should just be created by a call to Docker.create_container, and not actually started.\n\nKeyword arguments supported by work should be included in that types documentation.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.filename-Union{Tuple{T}, Tuple{T}, Tuple{T,Any}} where T<:Launcher.AbstractWorkload",
    "page": "Docstrings",
    "title": "Launcher.filename",
    "category": "method",
    "text": "filename(work::AbstractWorkload)\n\nCreate a filename for work based on the data type of work and the arguments.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.getargs-Tuple{Launcher.AbstractWorkload}",
    "page": "Docstrings",
    "title": "Launcher.getargs",
    "category": "method",
    "text": "getargs(work::AbstractWorkloads)\n\nReturn the commandline arguments for work. Falls back to work.args. Extend this method for a workload if the fallback is not appropriate.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.inception_cluster-Tuple{}",
    "page": "Docstrings",
    "title": "Launcher.inception_cluster",
    "category": "method",
    "text": "inception_cluster(;kw...)\n\nSummary of Keyword arguments:\n\nnworkers: Number of worker nodes in the cluster. Default: 1\ncpusets::Vector{String}: The CPUs to assign to each worker. \nmemsets::Vector{String}: NUMA nodes to assign to each worker.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.instantiate-Tuple{Launcher.AbstractDockerImage}",
    "page": "Docstrings",
    "title": "Launcher.instantiate",
    "category": "method",
    "text": "instantiate(image::AbstractDockerImage)\n\nPerform all the necessary build steps to build and tag the docker image for image.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.isrunning-Tuple{Docker.Container}",
    "page": "Docstrings",
    "title": "Launcher.isrunning",
    "category": "method",
    "text": "Launcher.isrunning(container::Container) -> Bool\n\nReturn true if container is running.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.tf_timeparser-Tuple{String}",
    "page": "Docstrings",
    "title": "Launcher.tf_timeparser",
    "category": "method",
    "text": "Launcher.tf_timeparser(file::String) -> Float64\n\nReturn the average time per step of a tensorflow based training run stored in io.  Applicable when the output of the log is in the format shown below\n\nI0125 15:02:43.353371 140087033124608 tf_logging.py:115] loss = 11.300481, step = 2 (10.912 sec)\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.translator_parser-Tuple{String}",
    "page": "Docstrings",
    "title": "Launcher.translator_parser",
    "category": "method",
    "text": "Launcher.translator_parser(file::String) -> Float64\n\nReturn the mean time per step from an output log file for the Launcher.Translator workload.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.uid-Tuple{}",
    "page": "Docstrings",
    "title": "Launcher.uid",
    "category": "method",
    "text": "Launcher.uid()\n\nReturn the user ID of the current user.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.username-Tuple{}",
    "page": "Docstrings",
    "title": "Launcher.username",
    "category": "method",
    "text": "Launcher.username()\n\nReturn the name of the current user.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Docstrings-1",
    "page": "Docstrings",
    "title": "Docstrings",
    "category": "section",
    "text": "Modules = [Launcher]\nFilter = x -> !isa(x, Launcher.AbstractWorkload)"
},

{
    "location": "workloads/slim/#",
    "page": "Tensorflow Slim",
    "title": "Tensorflow Slim",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/slim/#Tensorflow-Slim-1",
    "page": "Tensorflow Slim",
    "title": "Tensorflow Slim",
    "category": "section",
    "text": "This is actually a collection of models implemented using using Tensorflow\'s Slim framework. The original repo for these models is  https://github.com/tensorflow/models/tree/master/research/slim.When I benchmarked this against the official tensorflow models for Resnet, this  implementation seemed to train a little faster. Plus, the official models did not have VGG implemented, which is why I ended up using this implementation."
},

{
    "location": "workloads/slim/#Launcher.Slim",
    "page": "Tensorflow Slim",
    "title": "Launcher.Slim",
    "category": "type",
    "text": "Struct representing parameters for launching the Tensorflow Official Resnet Model on the  Imagenet training set. Construct type using a key-word constructor\n\nFields\n\nargs::NamedTuple - Arguments passed to the Keras Python script that creates and    trains Resnet.\ninteractive::Bool - Set to true to create a container that does not automatically run   Resnet when launched. Useful for debugging what\'s going on inside the container.\n\ncreate keywords\n\nmemory::Union{Nothing, Int} - The amount of memory to assign to this container. If   this value is nothing, the container will have access to all system memory.   Default: nothing.\ncpuSets = \"\" - The CPU sets on which to run the workload. Defaults to all processors.    Examples: \"0\", \"0-3\", \"1,3\".\n\n\n\n\n\n"
},

{
    "location": "workloads/slim/#Using-from-Launcher-1",
    "page": "Tensorflow Slim",
    "title": "Using from Launcher",
    "category": "section",
    "text": "Launcher.SlimNavigate to the Launcher/ directory, and launch julia with the commandjulia --projectFrom inside Julia, to launch resnet 50 with a batchsize of 32, use the following command:julia> using Launcher\n\njulia> workload = Launcher.Slim(args = (model_name = \"resnet_v1_50\", batchsize = 32))Valid NetworksThe following is the list of valid inputs for the model_name argument:alexnet_v2\ncifarnet\noverfeat\nvgg_a\nvgg_16\nvgg_19\nvgg_416\ninception_v1\ninception_v2\ninception_v3\ninception_v4\ninception_resnet_v2\nlenet\nresnet_v1_50\nresnet_v1_101\nresnet_v1_152\nresnet_v1_200\nresnet_v2_50\nresnet_v2_101\nresnet_v2_152\nresnet_v2_200\nmobilenet_v1\nmobilenet_v1_075\nmobilenet_v1_050\nmobilenet_v1_025\nmobilenet_v2\nmobilenet_v2_140\nmobilenet_v2_035\nnasnet_cifar\nnasnet_mobile\nnasnet_large\npnasnet_large\npnasnet_mobile"
},

{
    "location": "workloads/slim/#Automatically-Applied-Arguments-1",
    "page": "Tensorflow Slim",
    "title": "Automatically Applied Arguments",
    "category": "section",
    "text": "These are arguments automatically supplied by Launcher.--dataset_dir: Binds the dataset at imagenet_tf_slim into /imagenet in the container.\n--dataset_name: Defaults to imagenet.\nclone_on_cpu: Defaults to true."
},

{
    "location": "workloads/slim/#Script-Arguments:-1",
    "page": "Tensorflow Slim",
    "title": "Script Arguments:",
    "category": "section",
    "text": "Generic training script that trains a model using a given dataset.\nflags:\n\n/models/slim/train_image_classifier.py:\n  --adadelta_rho: The decay rate for adadelta.\n    (default: \'0.95\')\n    (a number)\n  --adagrad_initial_accumulator_value: Starting value for the AdaGrad accumulators.\n    (default: \'0.1\')\n    (a number)\n  --adam_beta1: The exponential decay rate for the 1st moment estimates.\n    (default: \'0.9\')\n    (a number)\n  --adam_beta2: The exponential decay rate for the 2nd moment estimates.\n    (default: \'0.999\')\n    (a number)\n  --batch_size: The number of samples in each batch.\n    (default: \'32\')\n    (an integer)\n  --checkpoint_exclude_scopes: Comma-separated list of scopes of variables to exclude when restoring from a checkpoint.\n  --checkpoint_path: The path to a checkpoint from which to fine-tune.\n  --[no]clone_on_cpu: Use CPUs to deploy clones.\n    (default: \'false\')\n  --dataset_dir: The directory where the dataset files are stored.\n  --dataset_name: The name of the dataset to load.\n    (default: \'imagenet\')\n  --dataset_split_name: The name of the train/test split.\n    (default: \'train\')\n  --end_learning_rate: The minimal end learning rate used by a polynomial decay learning rate.\n    (default: \'0.0001\')\n    (a number)\n  --ftrl_initial_accumulator_value: Starting value for the FTRL accumulators.\n    (default: \'0.1\')\n    (a number)\n  --ftrl_l1: The FTRL l1 regularization strength.\n    (default: \'0.0\')\n    (a number)\n  --ftrl_l2: The FTRL l2 regularization strength.\n    (default: \'0.0\')\n    (a number)\n  --ftrl_learning_rate_power: The learning rate power.\n    (default: \'-0.5\')\n    (a number)\n  --[no]ignore_missing_vars: When restoring a checkpoint would ignore missing variables.\n    (default: \'false\')\n  --label_smoothing: The amount of label smoothing.\n    (default: \'0.0\')\n    (a number)\n  --labels_offset: An offset for the labels in the dataset. This flag is primarily used to evaluate the VGG and ResNet architectures which do not use a background class for the ImageNet\n    dataset.\n    (default: \'0\')\n    (an integer)\n  --learning_rate: Initial learning rate.\n    (default: \'0.01\')\n    (a number)\n  --learning_rate_decay_factor: Learning rate decay factor.\n    (default: \'0.94\')\n    (a number)\n  --learning_rate_decay_type: Specifies how the learning rate is decayed. One of \"fixed\", \"exponential\", or \"polynomial\"\n    (default: \'exponential\')\n  --log_every_n_steps: The frequency with which logs are print.\n    (default: \'10\')\n    (an integer)\n  --master: The address of the TensorFlow master to use.\n    (default: \'\')\n  --max_number_of_steps: The maximum number of training steps.\n    (an integer)\n  --model_name: The name of the architecture to train.\n    (default: \'inception_v3\')\n  --momentum: The momentum for the MomentumOptimizer and RMSPropOptimizer.\n    (default: \'0.9\')\n    (a number)\n  --moving_average_decay: The decay to use for the moving average.If left as None, then moving averages are not used.\n    (a number)\n  --num_clones: Number of model clones to deploy. Note For historical reasons loss from all clones averaged out and learning rate decay happen per clone epochs\n    (default: \'1\')\n    (an integer)\n  --num_epochs_per_decay: Number of epochs after which learning rate decays. Note: this flag counts epochs per clone but aggregates per sync replicas. So 1.0 means that each clone will go\n    over full epoch individually, but replicas will go once across all replicas.\n    (default: \'2.0\')\n    (a number)\n  --num_preprocessing_threads: The number of threads used to create the batches.\n    (default: \'4\')\n    (an integer)\n  --num_ps_tasks: The number of parameter servers. If the value is 0, then the parameters are handled locally by the worker.\n    (default: \'0\')\n    (an integer)\n  --num_readers: The number of parallel readers that read data from the dataset.\n    (default: \'4\')\n    (an integer)\n  --opt_epsilon: Epsilon term for the optimizer.\n    (default: \'1.0\')\n    (a number)\n  --optimizer: The name of the optimizer, one of \"adadelta\", \"adagrad\", \"adam\",\"ftrl\", \"momentum\", \"sgd\" or \"rmsprop\".\n    (default: \'rmsprop\')\n  --preprocessing_name: The name of the preprocessing to use. If left as `None`, then the model_name flag is used.\n  --quantize_delay: Number of steps to start quantized training. Set to -1 would disable quantized training.\n    (default: \'-1\')\n    (an integer)\n  --replicas_to_aggregate: The Number of gradients to collect before updating params.\n    (default: \'1\')\n    (an integer)\n  --rmsprop_decay: Decay term for RMSProp.\n    (default: \'0.9\')\n    (a number)\n  --rmsprop_momentum: Momentum.\n    (default: \'0.9\')\n    (a number)\n  --save_interval_secs: The frequency with which the model is saved, in seconds.\n    (default: \'600\')\n    (an integer)\n  --save_summaries_secs: The frequency with which summaries are saved, in seconds.\n    (default: \'600\')\n    (an integer)\n  --[no]sync_replicas: Whether or not to synchronize the replicas during training.\n    (default: \'false\')\n  --task: Task id of the replica running the training.\n    (default: \'0\')\n    (an integer)\n  --train_dir: Directory where checkpoints and event logs are written to.\n    (default: \'/tmp/tfmodel/\')\n  --train_image_size: Train image size\n    (an integer)\n  --trainable_scopes: Comma-separated list of scopes to filter the set of variables to train.By default, None would train all the variables.\n  --weight_decay: The weight decay on the model weights.\n    (default: \'4e-05\')\n    (a number)\n  --worker_replicas: Number of worker replicas.\n    (default: \'1\')\n    (an integer)"
},

{
    "location": "workloads/slim/#Dataset-1",
    "page": "Tensorflow Slim",
    "title": "Dataset",
    "category": "section",
    "text": "This workload uses the Imagenet dataset."
},

{
    "location": "workloads/slim/#File-Changes-1",
    "page": "Tensorflow Slim",
    "title": "File Changes",
    "category": "section",
    "text": "train_image_classifier.pyLine 62: Change default value of log_every_n_steps from 10 to 5."
},

{
    "location": "workloads/cifarcnn/#",
    "page": "Cifar Cnn",
    "title": "Cifar Cnn",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/cifarcnn/#Launcher.CifarCnn",
    "page": "Cifar Cnn",
    "title": "Launcher.CifarCnn",
    "category": "type",
    "text": "Workload object for the Keras Cifar10 cnn. Build type using keyword constructors.\n\nFields\n\nargs :: NamedTuple - Arguments to pass to the startup script (see docs).    Default: NamedTuple()\ninteractive :: Bool - If set to true, the container will launch into /bin/bash   instead of Python. Used for debugging the container. Default: false.\n\n\n\n\n\n"
},

{
    "location": "workloads/cifarcnn/#Cifar-Cnn-1",
    "page": "Cifar Cnn",
    "title": "Cifar Cnn",
    "category": "section",
    "text": "A simple CNN for training on the cifar-10 dataset. This model is small enough that a couple epochs of training takes a reasonably short amount of time, even when snooping memory.File name: /workloads/keras/cifar_cnn.py\nContainer entry point: /home/startup/cifar_cnn.py\nDataset: cifar-10-batches-py.tar.gz    (https://www.cs.toronto.edu/~kriz/cifar-10-python.tar.gz)\nEndpoint for dataset in container: /home/user/.keras/datasets/cifar-10-batches-py.tar.gz.   If dataset doesn\'t exist, it will automatically be downloaded. However, this can take   a while and is a bit rude to the site hosting the dataset.\nScript Arguments:\n--batchsize [size] : Configure the batch size for training.\n--epochs [n] : Train for n epochs\n--abort : Import the keras and tensorflow libraries and then exit. Used for    testing the overhead of code loading.Launcher Docs:Launcher.CifarCnn"
},

{
    "location": "workloads/test/#",
    "page": "Test Workload",
    "title": "Test Workload",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/test/#Test-Workload-1",
    "page": "Test Workload",
    "title": "Test Workload",
    "category": "section",
    "text": "Workloads that run under the official ubuntu docker image."
},

{
    "location": "workloads/test/#Test-1",
    "page": "Test Workload",
    "title": "Test",
    "category": "section",
    "text": "A simple shell script that prints a message, sleeps for a few seconds, prints another message and exits. The point of this workload is to provide a simple and quick to run test to decrease debugging time.File name: /workloads/ubuntu/sleep.sh\nContainer entry point: /home/startup/sleep.shLauncher DocsLauncher.TestWorkload"
},

{
    "location": "datasets/imagenet/#",
    "page": "Imagenet",
    "title": "Imagenet",
    "category": "page",
    "text": ""
},

{
    "location": "datasets/imagenet/#Imagenet-1",
    "page": "Imagenet",
    "title": "Imagenet",
    "category": "section",
    "text": "Navigate to the directory where the dataset will live. We are going to use an  unofficial Kaggle CLI that supports resuming  downloads to download the dataset.Sign up for Kaggle and register for the imagenet challenge at https://www.kaggle.com/c/imagenet-object-localization-challenge/dataLaunch a docker container withdocker run -v $PWD:/data -it --rm python:3.6 /bin/bashInside the container:pip3 install kaggle-cli\ncd data\nkg download -c imagenet-object-localization-challenge -u <username> -p <password>"
},

{
    "location": "datasets/imagenet/#Slim-Preprocessing-1",
    "page": "Imagenet",
    "title": "Slim Preprocessing",
    "category": "section",
    "text": "This collection of models uses the Imagenet dataset."
},

{
    "location": "datasets/imagenet/#Preparation-steps-(don\'t-need-to-repeat)-1",
    "page": "Imagenet",
    "title": "Preparation steps (don\'t need to repeat)",
    "category": "section",
    "text": "The code in this repo is taken from the build process that comes in the slim project. However, I\'ve modified it so it works without having to go through Bazel (I don\'t really know why that was used in the first place) and also updated it so it works with Python3.Changes made to builddownload_and_convert_imagenet.sh\nRemoved some build comments that are no longer relevant.\nLine 59: Change path for WORK_DIR since we\'re no longer doing the Bazel style   build.\nLine 104: Change path to build_iamgenet_data.py.\nLine 108: Put python3 in front of script invocation. Get around executable   permission errors.\ndatasets/build_imagenet_data.py\nLines 213, 216, 217, and 224: Suffix .encode() on string arguments to pass them   as bytes to _bytes_feature.\nLines 527: Wrap range(len(filenames)) in list() to materialize the lazy range   type.\ndatasets/download_imagenet.sh\nLines 72 and 81: Comment out wget commands, avoid downloading imagenet training   and validation data.\ndatasets/preprocess_imagenet_validation_data.py\nLine 1: #!/usr/bin/python -> #!/usr/bin/python3\nRemove importing of six.moves module.\nChange all instances of xrange to range. The range type in python3 behaves   just like the xrange type.\ndatasets/process_bounding_boxes.py\nLine 1: #!/usr/bin/python -> #!/usr/bin/python3\nRemove importing of six.moves module.\nChange all instance of xrange to range."
},

{
    "location": "datasets/rnn/#",
    "page": "RNN Translator",
    "title": "RNN Translator",
    "category": "page",
    "text": ""
},

{
    "location": "datasets/rnn/#RNN-Translator-1",
    "page": "RNN Translator",
    "title": "RNN Translator",
    "category": "section",
    "text": "This is the dataset for the project originally belonging to ML-Perf. The exact link to the project is: https://github.com/mlperf/training/tree/master/rnn_translator. To install this dataset, simply runml-tools/datasets/rnn_translator/download_dataset.sh [dataset directory]"
},

{
    "location": "datasets/rnn/#Changes-made-to-the-download-script-1",
    "page": "RNN Translator",
    "title": "Changes made to the download script",
    "category": "section",
    "text": "At the end of the script (lines 172 to 175), I added the following:# Move everything in the output dir into the data dir\nmv ${OUTPUT_DIR}/*.de ${OUTPUT_DIR_DATA}\nmv ${OUTPUT_DIR}/*.en ${OUTPUT_DIR_DATA}\nmv ${OUTPUT_DIR}/*.32000 ${OUTPUT_DIR_DATA}It seems that the verify_dataset.sh script expects these files to be in the data/  subdirectory, so this automates that process.NoteThe verify_dataset.sh script should be run in the top level directory where the dataset was downloaded to because of hard coded paths."
},

{
    "location": "datasets/brats/#",
    "page": "BraTS",
    "title": "BraTS",
    "category": "page",
    "text": ""
},

{
    "location": "datasets/brats/#BraTS-1",
    "page": "BraTS",
    "title": "BraTS",
    "category": "section",
    "text": "Brain Tumor Segmentation library. Specifically, the 2018 edition. Getting this dataset is kind of a pain because you have to register, and then the people hosting the registration don\'t actually tell you when your registration is ready.More information can be found at https://www.med.upenn.edu/sbia/brats2018/data.htmlOnce you have the zip file of the data, titled MICCAI_BraTS_2018_Data_Training.zip,  getting it into a format that is useable by the 3dUnetCNN workload is pretty involved:"
},

{
    "location": "datasets/brats/#Preprocessing-1",
    "page": "BraTS",
    "title": "Preprocessing",
    "category": "section",
    "text": "Create a directory where the dataset will go, and make a folder called \"original\" in it.mkdir ~/brats\ncd brats\nmkdir original\ncd originalMove the zip file into the original foldermv <zip-path> .Unzip the contents of the fileunzip `MICCAI_BraTS_2018_Data_Training.zip`Now, go build the docker container darchr/3dunet (see the 3dunet page). Once that is done, run the preprocess.sh script in workloads/3dUnet/dataset/preprocess.sh using./preprocess.sh ~/bratsGo have a snack while this thing runs. I\'m sorry if you don\'t have a machine with 96  processors because it will take a while.Once the preprocess script is done, there\'s still more preprocessing to do. Unfortunately, factoring out the code that runs this step proved to be more challenging than I was willing to deal with, so you will have to run this workload. Basically, the first step that the  3dUnet implementation does is to turn all the preprocessed files into a gigantic hdf5 file. But, it only has to do it once.Make sure you register the location of the brats data repo in Launcher withcd Launcher\n\njuliajulia> using Launcher\n\njulia> Launcher.edit_setup()Then, run the workload withjulia> workload = Launcher.Unet()\n\njulia> run(workload)Wait patiently the initial conversion to hdf5 to complete. Once it does, you\'ll never have to deal with this stuff again (hopefully)."
},

{
    "location": "datasets/brats/#Problems-Solutions-1",
    "page": "BraTS",
    "title": "Problems + Solutions",
    "category": "section",
    "text": "The python:3.5.6 docker container had a operating system that was to old for the compilers/   cmake versions to build ANTs. Thus, I switched darchr/tensorflow-mkl to be based on   ubuntu 18.04 and build python 3.5.6 from source in that container.\nWhen building ANTs, the make process would just hang when trying to download TKv5 (or    something with a name very similar to that). The problem was with the git protocol used   to clone the repository. The solution to this was to pass a flag to cmake:cmake -DSuperBuild_ANTS_USE_GIT_PROTOCOL=OFF ../ANTsThe 3dUnet implementation, especially the data loading from the HDF5 file is insanely    buggy - it would immediately segfault then loading data. My solutions to this, taken    from comments of users in issues for the repository, was to\nTurn off compresion into the HDF5 file in data.py, line 12: change the key word    arguments to just complevel=0\nEnable multithreading in the training loop training.py: add the argument   use_multiprocessing = True to the fall to fit_generator on line 78."
},

{
    "location": "manifest/#",
    "page": "Manifest",
    "title": "Manifest",
    "category": "page",
    "text": ""
},

{
    "location": "manifest/#Manifest-1",
    "page": "Manifest",
    "title": "Manifest",
    "category": "section",
    "text": "Below is summary of projects supporting this repo as well as resources provisioned on shared machines for bookkeeping purposes.Pages = [\"manifest.md\"]\nDepth = 3"
},

{
    "location": "manifest/#Supporting-Projects-1",
    "page": "Manifest",
    "title": "Supporting Projects",
    "category": "section",
    "text": ""
},

{
    "location": "manifest/#[Docker](https://github.com/hildebrandmw/Docker.jl)-1",
    "page": "Manifest",
    "title": "Docker",
    "category": "section",
    "text": "Julia interface to the Docker API for managing containers and gathering metrics. This  package is based on the original Docker package, but updated to serve our own needs. I\'ve also added CI to the build process."
},

{
    "location": "manifest/#TODO-List-(Low-Priority)-1",
    "page": "Manifest",
    "title": "TODO List (Low Priority)",
    "category": "section",
    "text": "Add documentation of features in README. No need for auto docs.\nEventually, I would like to get this merged with the original Docker package, which would   likely involve:\nForking the original Docker repo.\nMigrating the code in Docker to the forked Docker repo.\nIssue a string of pull requests to get the functionality migrated.\nThe Docker daemon by default listens on a Unix socket. In order to get the    HTTP to talk to a Unix socket, I had to extend   some of the methods in HTTP. Contributing this code to HTTP would be a good    contribution I think."
},

{
    "location": "manifest/#[PAPI](https://github.com/hildebrandmw/PAPI.jl)-1",
    "page": "Manifest",
    "title": "PAPI",
    "category": "section",
    "text": "Updated bindings to the PAPI Library, forked from the original PAPI.jl which has not been updated in 4 years. This package includes the PAPI executable for reproducibility, courtesy of  PAPIBuilder2, which is auto built with BinaryBuilder.In essence, this gives access to a processor\'s hardware event counters through perf."
},

{
    "location": "manifest/#TODO-List-(Low-Priority)-2",
    "page": "Manifest",
    "title": "TODO List (Low Priority)",
    "category": "section",
    "text": "Get CI working for this package. I don\'t think the hardware performance counters are   available in Travis Docker containers, so the current test suite fails due to a PAPI    error.\nFinish implementing the rest of the Low Level Library\nImplement the high level library, taking inspiration from the original PAPI implementation   and the python bindings.\nAdd fuller documentation\nDocument the Julia-side API that I use to interact with it. This side is mainly    responsible for automatically handling library initialization and cleanup."
},

{
    "location": "manifest/#[PAPIBuilder2](https://github.com/hildebrandmw/PAPIBuilder2)-1",
    "page": "Manifest",
    "title": "PAPIBuilder2",
    "category": "section",
    "text": "Builder for the PAPI library. Releases fetched when installing can be found here:  https://github.com/hildebrandmw/PAPIBuilder2/releases"
},

{
    "location": "manifest/#[SystemSnoop](https://github.com/hildebrandmw/SystemSnoop.jl)-1",
    "page": "Manifest",
    "title": "SystemSnoop",
    "category": "section",
    "text": "Snooping routines to gather metrics on running programs. Includes the following analyses:Idle page tracking\nHardware performance counter tracking through PAPI.One of the big goals of this package is to reduce the number of third party dependencies as much as possible since Idle Page Tracking requires Julia to be run as root."
},

{
    "location": "manifest/#TODO-List-(Med-Priority)-1",
    "page": "Manifest",
    "title": "TODO List (Med Priority)",
    "category": "section",
    "text": "Add support for monitoring multiple processes.\nHave other people use this package to find bugs and improve documentation."
},

{
    "location": "manifest/#[ml-notebooks-(private)](https://github.com/darchr/ml-notebooks)-1",
    "page": "Manifest",
    "title": "ml-notebooks (private)",
    "category": "section",
    "text": "Jupyter notebooks and scripts for research."
},

{
    "location": "manifest/#[X-Mem](https://github.com/hildebrandmw/X-Mem)-1",
    "page": "Manifest",
    "title": "X-Mem",
    "category": "section",
    "text": "Fork of the Microsoft X-Mem repositoy. I\'ve added a little bit to it toEnsure latency pointer chasing traverses the whole working set.\nAllows a file to be used the source for memory allocation of the working set. This lets   us a memory mapped file on a persistent memory device to give us direct access to that   device so we can take measurements of it, assuming the file is mounted on a direct    access file system. (worst sentence ever)"
},

{
    "location": "manifest/#[XMem](https://github.com/hildebrandmw/XMem.jl)-1",
    "page": "Manifest",
    "title": "XMem",
    "category": "section",
    "text": "Julia package for dealing with X-Mem. Auto builds the binary, launches it, controls flags, all that fun stuff."
},

{
    "location": "manifest/#[Checkpoints](https://github.com/hildebrandmw/Checkpoints.jl)-1",
    "page": "Manifest",
    "title": "Checkpoints",
    "category": "section",
    "text": "I got very tired of suffering jupyter notebook apocalypses. This pacakge helps avoid that by managing storing results of long running computations so I can close down the notebook but still have the results. It\'s actuallyh quite convenient."
},

{
    "location": "manifest/#[PCM](https://github.com/hildebrandmw/PCM.jl)-1",
    "page": "Manifest",
    "title": "PCM",
    "category": "section",
    "text": "Very experimental wrapper around PCM, but provides access to per-channel DRAM read/write counters and per-dimm PMEM read/write counters, as well as DRAM cache hit-rate when  operating in 2LM."
},

{
    "location": "manifest/#Resources-on-Shared-Machines-1",
    "page": "Manifest",
    "title": "Resources on Shared Machines",
    "category": "section",
    "text": ""
},

{
    "location": "manifest/#Drives-on-amarillo-1",
    "page": "Manifest",
    "title": "Drives on amarillo",
    "category": "section",
    "text": "The drive/data1/ml-dataseton amarillo is the home of the datasets used."
},

{
    "location": "nvm/swap/#",
    "page": "Swap",
    "title": "Swap",
    "category": "page",
    "text": ""
},

{
    "location": "nvm/swap/#Swap-1",
    "page": "Swap",
    "title": "Swap",
    "category": "section",
    "text": "For some timing experiments, we reduce the amount of DRAM available to the docker container, and instead allow it to use swap on an Optane drive. This is initially for exploration of how decreasing memory affects performace of CPU training. Below is outlined the process of setting up and removing swap partitions."
},

{
    "location": "nvm/swap/#Partitioning-the-Drive-1",
    "page": "Swap",
    "title": "Partitioning the Drive",
    "category": "section",
    "text": "First, I created a partition on the NVM drive withsudo fdisk /dev/nvme0n1Then proceeded with the options: n (new partition) \np (primary partiton)\n1 (partition number)\nDefault sectors\nw (write this information to disk)The output of fdisk looked like belowWelcome to fdisk (util-linux 2.31.1).\nChanges will remain in memory only, until you decide to write them.\nBe careful before using the write command.\n\nDevice does not contain a recognized partition table.\nCreated a new DOS disklabel with disk identifier 0xe142f7ae.\n\nCommand (m for help): n\nPartition type\n   p   primary (0 primary, 0 extended, 4 free)\n   e   extended (container for logical partitions)\nSelect (default p): p\nPartition number (1-4, default 1): 1\nFirst sector (2048-1875385007, default 2048):\nLast sector, +sectors or +size{K,M,G,T,P} (2048-1875385007, default 1875385007):\n\nCreated a new partition 1 of type \'Linux\' and of size 894.3 GiB.\n\nCommand (m for help): w\nThe partition table has been altered.\nCalling ioctl() to re-read partition table.\nSyncing disks.Running lsblk revealed the following now for the NVM drivenvme0n1     259:0    0 894.3G  0 disk\n└─nvme0n1p1 259:2    0 894.3G  0 part"
},

{
    "location": "nvm/swap/#Creating-a-file-system-and-mounting-1",
    "page": "Swap",
    "title": "Creating a file system and mounting",
    "category": "section",
    "text": "Then, I created a file system on the drive withsudo mkfs -t ext4 /dev/nvme0n1p1I created a directory and mounted the drive:sudo mkdir /mnt/nvme\nsudo mount /dev/nvme0n1p1 /mnt/nvme"
},

{
    "location": "nvm/swap/#Configuring-Swap-1",
    "page": "Swap",
    "title": "Configuring Swap",
    "category": "section",
    "text": "sudo fallocate -l 32g /mnt/nvme/32gb.swap\nsudo chmod 0600 /mnt/nvme/32gb.swap\nsudo mkswap /mnt/nvme/32gb.swap\nsudo swapon -p 0 /mnt/nvme/32gb.swapVerify that the file is being used as swap usingswapon -s"
},

{
    "location": "nvm/swap/#Removing-Swap-1",
    "page": "Swap",
    "title": "Removing Swap",
    "category": "section",
    "text": "To remove the swapfile from system swap, just usesudo swapoff /mnt/nvme/32gb.swap"
},

{
    "location": "extra/perf/#",
    "page": "PAPI Notes",
    "title": "PAPI Notes",
    "category": "page",
    "text": ""
},

{
    "location": "extra/perf/#PAPI-Notes-1",
    "page": "PAPI Notes",
    "title": "PAPI Notes",
    "category": "section",
    "text": "The following issues about PAPI are either known or were discovered:Some hardware performance counters such as single precision and double precision floating   point instruction counters do not seem to work on AMD EPYC processors:   https://bitbucket.org/icl/papi/issues/56/dp-and-sp-validation-tests-on-amd\nPAPI version stable-5.6.0: Function PAPI_read (and related functions that read from   event counters) trigger an integer divide by zero exception on the AMD EPYC system I    tried, rendering this version unusable. It\'s possible that this would work on Intel    hardware, but I haven\'t tried.\nPAPI master 0fdac4fc7f95f0ac8039e431419a5133088911af: Reads from hardware counters    monitoring L1 cache loads and stores (as well as loads and stores for other levels   in the memory hierarchy) return negative numbers both consistently and sporadically on    Intel systems. The hardware counters I believe are 48-bits, thus we should not be seeing   any counter overflow. I\'m calling this a bug.\nPAPI version stable-5.5.0: No hardware events are recognized on the Intel system.    I think this may be due to libpfm being an older version.\nThe version of PAPI that works for me and seems to return consistent and reasonable results   across trials is stable-5.5.1. However, this version is old and I have concerns that   it may be lacking support for newer generations of processors (i.e. Cascade Lake)    Final Solution: After playing around with git bisesct, I discovered that the integer division bug cropped up when reading of performance counters via the rdpmc instruction was switched to the default (sometime after the 5.5.1 release). The rdpmc instruction is a x86 instruction for reading quickly from the performance counters. It seems that the PAPI implementation of using this instruction is quite buggy. By compiling PAPI with rdpmc turned off:./configure --enable-perfevent-rdpmc=noI was once again getting consistent and sensible numbers. Thus, I finally ended up using the master released, but disabling rdpmc."
},

{
    "location": "extra/perf/#Finding-Perf-Codes-1",
    "page": "PAPI Notes",
    "title": "Finding Perf Codes",
    "category": "section",
    "text": "A VERY helpful resource for finding event codes and such:  http://www.bnikolic.co.uk/blog/hpc-prof-events.html."
},

]}
