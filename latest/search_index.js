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
    "text": "The workloads are all up into individual workloads, each of which has their own documentation. Below is an example of running Resnet 50:cd Launcher\njulia --projectInside the Julia REPL:julia> using Launcher\n\njulia> workload = TFBenchmark(args = (model = \"resnet50_v2\", batch_size = 32))\nTFBenchmark\n  args: NamedTuple{(:model, :batch_size),Tuple{String,Int64}}\n  interactive: Bool false\n\njulia> run(workload)This will create a docker container running Resnet 50 that will keep running until you interrupt it with ctrl + C."
},

{
    "location": "launcher/launcher/#Saving-Output-Log-to-a-File-1",
    "page": "Tutorial",
    "title": "Saving Output Log to a File",
    "category": "section",
    "text": "To run a workload and save the stdout to a file for later analysis, you may pass an open file handle as the log keyword of the run function:julia> using Launcher\n\njulia> workload = TFBenchmark(args = (model = \"resnet50_v2\", batch_size = 32))\n\n# Open `log.txt` and pass it to `run`. When `run` exists (via `ctrl + C` or other means),\n# the container\'s stdout will be saved into `log.txt`.\njulia>  open(\"log.txt\"; write = true) do f\n            run(workload; log = f)\n        end"
},

{
    "location": "launcher/launcher/#Running-a-Container-for-X-seconds-1",
    "page": "Tutorial",
    "title": "Running a Container for X seconds",
    "category": "section",
    "text": "The run function optionally accepts an arbitrary function as its first argument, to which it passes a handle to the Docker container is created. This lets you do anything you want with the guarentee that the container will be successfully cleaned up if things go south. If you just want to run the container for a certain period of time, you can do something like the following:julia> using Launcher\n\njulia> workload = TFBenchmark(args = (model = \"resnet50_v2\", batch_size = 32))\n\n# Here, we use Julia\'s `do` syntax to implicatly pass a function to the first\n# argument of `run`. In this function, we sleep for 10 seconds before returning. When we\n# return, the function `run` exits.\njulia>  run(workload) do container\n            sleep(10)\n        end"
},

{
    "location": "launcher/launcher/#Gathering-Performance-Metrics-1",
    "page": "Tutorial",
    "title": "Gathering Performance Metrics",
    "category": "section",
    "text": "One way to gather the performance of a workload is to simply time how long it runs for.julia> runtime = @elapsed run(workload)However, for long running workloads like DNN training, this is now always feasible. Another approach is to parse through the container\'s logs and use its self reported times. There are a couple of functions like Launcher.benchmark_timeparser and  Launcher.translator_parser that provide this functionality for Tensorflow and  PyTorch based workloads respectively. See the docstrings for those functions for what  exactly they return. Example useage is shown below.julia> workload = Launcher.TFBenchmark(args = (model = \"resnet50_v2\", batch_size = 32))\n\njulia>  open(\"log.txt\"; write = true) do f\n            run(workload; log = f) do container\n                sleep(120)\n            end\n        end\n\njulia> mean_time_per_step = Launcher.benchmark_timeparser(\"log.txt\")"
},

{
    "location": "launcher/launcher/#Passing-Commandline-Arguments-1",
    "page": "Tutorial",
    "title": "Passing Commandline Arguments",
    "category": "section",
    "text": "Many workloads expose commandline arguments. These arguments can be passed from launcher using the args keyword argument to the workload constructor, like theargs = (model = \"resnet50_v2\", batch_size = 32)Which will be turned into--model=resnet50_v2 --batch_size=32when the script is invoked. In general, you will not have to worry about whether the result will be turned into --arg==value or --arg value since that is taken care of in the workload implementations. Do note, however, that using both the = syntax and space delimited syntax is not supported.If an argument has a hyphen - in it, such as batch-size, this is encoded in Launcher as a triple underscore ___. Thus, we would encode batch-size=32 asargs = (batch___size = 32,)"
},

{
    "location": "launcher/launcher/#Advanced-Example-1",
    "page": "Tutorial",
    "title": "Advanced Example",
    "category": "section",
    "text": "Below is an advanced example gathering performance counter data for a running workload.# Install packages\njulia> using Launcher, Pkg, Serialization, Dates\n\njulia> Pkg.add(PackageSpec(url = \"https://github.com/hildebrandmw/SystemSnoop.jl\"))\n\njulia> using SystemSnoop\n\njulia> workload = TFBenchmark(args = (model = \"resnet50_v2\", batch_size = 32))\n\n# Here, we use the SystemSnoop package to provide the monitoring using the `trace` funciton\n# in that package.\njulia>  data = open(\"log.txt\"; write = true) do f \n            # Obtain Samples every Second\n            sampler = SystemSnoop.SmartSample(Second(1))\n\n            # Collect data for 5 minutes\n            iter = SystemSnoop.Timeout(Minute(5))\n\n            # Launch the container. Get the PID of the container to pass to `trace` and then\n            # trace.\n            data = run(workload; log = f) do container\n                # We will measure the memory usage of our process over time.\n                measurements = (\n                    timestamp = SystemSnoop.Timestamp(),\n                    memory = SystemSnoop.Statm(),\n                )\n                return trace(getpid(container), measurements; iter = iter, sampletime = sampler)\n            end\n            return data\n        end\n\n# We can plot the memory usage over time from the resulting data\njulia> Pkg.add(\"UnicodePlots\"); using UnicodePlots\n\njulia> lineplot(getproperty.(data.memory, :resident))\n           ┌────────────────────────────────────────┐\n   2000000 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⡀⡀⠀⠀⠀⠀⠀⠀⠀⣀⡀⢀⣀⣀⡀⣀⣀⣀⡀│\n           │⠀⠀⠀⢰⠊⠉⠉⠉⠉⠉⠁⠈⠈⠁⠀⠀⠉⠉⠁⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀⠉⠉⠉⠀⠉⠈⠁⠈⠉│\n           │⠀⠀⠀⣸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⢠⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⠀⡼⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           │⠀⡖⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n         0 │⠴⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│\n           └────────────────────────────────────────┘\n           0                                      300\n\n# We can save the `data` datastructure for later using\njulia> serialize(\"my_data.jls\", data)\n\n# Finally, we can analyze the number of images per second\njulia> Launcher.benchmark_timeparser(\"log.txt\")\n24.7"
},

{
    "location": "launcher/launcher/#Constraining-Docker-Resources-1",
    "page": "Tutorial",
    "title": "Constraining Docker Resources",
    "category": "section",
    "text": "Extra keyword arguments passed to the run function will be forwarded to the function that constructs the Docker container. With these arguments, it is possible to  contstrain the resources available to the container. While certain workloads may define  extra keyword arguments, those documented in the docstring for run should apply to all workloads.To see how these might be used, suppose are are running on a system with 48 CPUs and 96  threads, with for NUMA nodes. Further, suppose we wanted to constraing our workload to only execute on CPUs attach to NUMA node 0, and only allocate memory in NUMA node zero. We could do that in the following way:julia> using Launcher\n\njulia> workload = TFBenchmark(args = (model = \"resnet50_v2\", batch_size = 32))\n\njulia> run(workload; cpuSets = \"0-11,48-59\", cpuMems = \"0\")"
},

{
    "location": "launcher/launcher/#Running-Multiple-Simultaneous-Workloads-1",
    "page": "Tutorial",
    "title": "Running Multiple Simultaneous Workloads",
    "category": "section",
    "text": "To run multiple different workloads simultaneously, use the Bundle and  BundleLogger types.julia> bundle = Bundle(workA, workB, workC)\n\njulia> logger = BundleLogger(bundle)\n\njulia> run(bundle; log = logger)\n\n# After completion, logs can get accessed via\njulia> log1 = logger[1]\n\njulia> log2 = logger[2]\n\njulia> log3 = logger[3]"
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
    "location": "launcher/docstrings/#Launcher.TFBenchmark",
    "page": "Docstrings",
    "title": "Launcher.TFBenchmark",
    "category": "type",
    "text": "Struct representing parameters for launching the Tensorflow Official Resnet Model on the  Imagenet training set. Construct type using a key-word constructor\n\nFields\n\nargs::NamedTuple - Arguments passed to the Keras Python script that creates and    trains Resnet.\ninteractive::Bool - Set to true to create a container that does not automatically run   Resnet when launched. Useful for debugging what\'s going on inside the container.\n\ncreate keywords\n\nmemory::Union{Nothing, Int} - The amount of memory to assign to this container. If   this value is nothing, the container will have access to all system memory.   Default: nothing.\ncpuSets = \"\" - The CPU sets on which to run the workload. Defaults to all processors.    Examples: \"0\", \"0-3\", \"1,3\".\n\n\n\n\n\n"
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
    "location": "launcher/docstrings/#Launcher.Bundle",
    "page": "Docstrings",
    "title": "Launcher.Bundle",
    "category": "type",
    "text": "Wrapper type for launching multiple workloads at the same time through the run command.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.Bundle-Tuple",
    "page": "Docstrings",
    "title": "Launcher.Bundle",
    "category": "method",
    "text": "Bundle(workloads...) -> Bundle\n\nWrap the workloads into a single type the will launch all workloads under run\n\nUsage is as follows:\n\nbundle = Bundle(workloadA, workloadB)\n\nrun(bundle)\n\nAny keywords passed to run will be forwarded to each workload wrapped in bundle.\n\nTo log the output of these workloads, see BundleLogger.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.BundleLogger-Tuple{Launcher.Bundle}",
    "page": "Docstrings",
    "title": "Launcher.BundleLogger",
    "category": "method",
    "text": "BundleLogger(bundle::Bundle) -> BundleLogger\n\nCreate a BundleLogger from bundle to pass to the log keyword argument of  run. This will store the logs for each container in bundle sequentially which can later be accessed by getindex. Example usage is shown below.\n\nbundle = Bundle(workA, workB, workC)\n\nlogger = BundleLogger(bundle)\n\nrun(bundle; log = logger)\n\n# After completion, logs can get accessed via\nlog1 = logger[1]\n\nlog2 = logger[2]\n\nlog3 = logger[3]\n\n\n\n\n\n"
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
    "text": "run([f::Function], work::AbstractWorkload; log::IO = devnull, kw...)\n\nCreate and launch a container from work with\n\ncontainer = create(work; kw...)\n\nStart the container and then call f(container). If f is not given, then attach to the container\'s stdout.\n\nThis function ensures that containers are stopped and cleaned up in case something goes wrong.\n\nAfter the container is stopped, write the log to IO\n\nKeyword Arguments\n\nExtra keyword arguments will be forwarded to the Docker.create. With these arguments, it  is possible to contstrain the resources available to the container. Standard arguments valid across all workloads are shown below:\n\nuser::String: The name of the user to run the container as. Default: \"\" (Root)\nentryPoint::String : The entry point for the container as a string or an array of    strings.  \nIf the array consists of exactly one empty string ([\"\"]) then the entry point is reset    to system default (i.e., the entry point used by docker when there is no ENTRYPOINT    instruction in the Dockerfile)\nDefault: \"\"\nmemory::Integer: Memory limit in bytes. Default: 0 (unlimited)\ncpuSets::String: CPUs in which to allow execution (e.g., 0-3, 0,1). Default: All CPUs\ncpuMems::String: Memory nodes (MEMs) in which to allow execution (0-3, 0,1). Only    effective on NUMA systems. Default: All NUMA nodea.\nenv::Vector{String}: A list of environment variables to set inside the container in the    form [\"VAR=value\", ...]. A variable without = is removed from the environment, rather    than to have an empty value. Default: []\nNOTE: Some workloads (especially those working with MKL) may automatically specify    some environmental variables. Consult the documentation for those workloads to see   which are specified.\n\n\n\n\n\n"
},

{
    "location": "launcher/docstrings/#Launcher.benchmark_timeparser-Tuple{String}",
    "page": "Docstrings",
    "title": "Launcher.benchmark_timeparser",
    "category": "method",
    "text": "Launcher.benchmark_timeparser(file::String) -> Float64\n\nReturn the average number of images processed per second by the [TFBenchmark] workload. Applicable when the output is of the form below:\n\nOMP: Info #250: KMP_AFFINITY: pid 1 tid 8618 thread 189 bound to OS proc set 93\nOMP: Info #250: KMP_AFFINITY: pid 1 tid 8619 thread 190 bound to OS proc set 94\nOMP: Info #250: KMP_AFFINITY: pid 1 tid 8620 thread 191 bound to OS proc set 95\nOMP: Info #250: KMP_AFFINITY: pid 1 tid 8621 thread 192 bound to OS proc set 0\nDone warm up\nStep	Img/sec	total_loss\n1	images/sec: 38.0 +/- 0.0 (jitter = 0.0)	7.419\n10	images/sec: 22.6 +/- 2.5 (jitter = 1.3)	7.593\n20	images/sec: 21.1 +/- 1.6 (jitter = 2.7)	7.597\n30	images/sec: 22.4 +/- 1.5 (jitter = 4.5)	7.683\n40	images/sec: 22.7 +/- 1.3 (jitter = 4.3)	7.576\n50	images/sec: 22.8 +/- 1.2 (jitter = 3.9)	7.442\n\n\n\n\n\n"
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
    "location": "launcher/docstrings/#Launcher.inception_timeparser-Tuple{String}",
    "page": "Docstrings",
    "title": "Launcher.inception_timeparser",
    "category": "method",
    "text": "Launcher.inception_timeparser(file::String) -> Float64\n\nReturn the average time per step of a tensorflow based training run stored in io.  Applicable when the output of the log is in the format shown below\n\nI0125 15:02:43.353371 140087033124608 tf_logging.py:115] loss = 11.300481, step = 2 (10.912 sec)\n\n\n\n\n\n"
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
    "location": "workloads/tf_benchmarks/#",
    "page": "Tensorflow Benchmarks",
    "title": "Tensorflow Benchmarks",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/tf_benchmarks/#Tensorflow-Benchmarks-1",
    "page": "Tensorflow Benchmarks",
    "title": "Tensorflow Benchmarks",
    "category": "section",
    "text": "This is a collection of models distributed by Tensorflow for benchmarking purposes: https://github.com/tensorflow/benchmarks. The code here supplies several models capable of working with Imagenet and Cifar"
},

{
    "location": "workloads/tf_benchmarks/#Using-From-Launcher-1",
    "page": "Tensorflow Benchmarks",
    "title": "Using From Launcher",
    "category": "section",
    "text": "Launcher.TFBenchmarksNavigate to the Launcher/ directory and launch Julia withjulia --projectFrom inside Julia, to launch resnet 50 with a batchsize of 32, use the following command:julia> using Launcher\n\njulia> workload = Launcher.TFBenchmarks(args = (model = \"resnet50_v2\", batchsize = 32))Valid Imagenet Modelsvgg11\nvgg16\nvgg19\nlenet\ngooglenet\noverfeat\nalexnet\ntrivial\ninception3\ninception4\nresnet50\nresnet50_v1.5\nresnet50_v2\nresnet101\nresnet101_v2\nresnet152\nresnet152_v2\nnasnet\nnasnetlarge\nmobilenet\nncf"
},

{
    "location": "workloads/tf_benchmarks/#Automatically-Applied-Arguments-1",
    "page": "Tensorflow Benchmarks",
    "title": "Automatically Applied Arguments",
    "category": "section",
    "text": "These are arguments automatically supplied by Launcher.--data_dir: Binds the dataset at imagenet_tf_slim into /imagenet in the container.\n--data_name: Defaults to imagenet.\n--device: cpu.\n--data_format: NCHW\n--mkl: Defaults to true."
},

{
    "location": "workloads/tf_benchmarks/#All-Script-Arguments-1",
    "page": "Tensorflow Benchmarks",
    "title": "All Script Arguments",
    "category": "section",
    "text": "absl.app:\n  -?,--[no]help: show this help\n    (default: \'false\')\n  --[no]helpfull: show full help\n    (default: \'false\')\n  --[no]helpshort: show this help\n    (default: \'false\')\n  --[no]helpxml: like --helpfull, but generates XML output\n    (default: \'false\')\n  --[no]only_check_args: Set to true to validate args and exit.\n    (default: \'false\')\n  --[no]pdb_post_mortem: Set to true to handle uncaught exceptions with PDB post mortem.\n    (default: \'false\')\n  --profile_file: Dump profile information to a file (for python -m pstats). Implies --run_with_profiling.\n  --[no]run_with_pdb: Set to true for PDB debug mode\n    (default: \'false\')\n  --[no]run_with_profiling: Set to true for profiling the script. Execution will be slower, and the output format might change over time.\n    (default: \'false\')\n  --[no]use_cprofile_for_profiling: Use cProfile instead of the profile module for profiling. This has no effect unless --run_with_profiling is set.\n    (default: \'true\')\n\nabsl.logging:\n  --[no]alsologtostderr: also log to stderr?\n    (default: \'false\')\n  --log_dir: directory to write logfiles into\n    (default: \'\')\n  --[no]logtostderr: Should only log to stderr?\n    (default: \'false\')\n  --[no]showprefixforinfo: If False, do not prepend prefix to info messages when it\'s logged to stderr, --verbosity is set to INFO level, and python logging is used.\n    (default: \'true\')\n  --stderrthreshold: log messages at this level, or more severe, to stderr in addition to the logfile.  Possible values are \'debug\', \'info\', \'warning\', \'error\', and \'fatal\'.  Obsoletes\n    --alsologtostderr. Using --alsologtostderr cancels the effect of this flag. Please also note that this flag is subject to --verbosity and requires logfile not be stderr.\n    (default: \'fatal\')\n  -v,--verbosity: Logging verbosity level. Messages logged at this level or lower will be included. Set to 1 for debug logging. If the flag was not set or supplied, the value will be changed\n    from the default of -1 (warning) to 0 (info) after flags are parsed.\n    (default: \'-1\')\n    (an integer)\n\nflags:\n  --adam_beta1: Beta2 term for the Adam optimizer\n    (default: \'0.9\')\n    (a number)\n  --adam_beta2: Beta2 term for the Adam optimizer\n    (default: \'0.999\')\n    (a number)\n  --adam_epsilon: Epsilon term for the Adam optimizer\n    (default: \'1e-08\')\n    (a number)\n  --agg_small_grads_max_bytes: If > 0, try to aggregate tensors of less than this number of bytes prior to all-reduce.\n    (default: \'0\')\n    (an integer)\n  --agg_small_grads_max_group: When aggregating small tensors for all-reduce do not aggregate more than this many into one new tensor.\n    (default: \'10\')\n    (an integer)\n  --all_reduce_spec: A specification of the all_reduce algorithm to be used for reducing gradients.  For more details, see parse_all_reduce_spec in variable_mgr.py.  An all_reduce_spec has\n    BNF form:\n    int ::= positive whole number\n    g_int ::= int[KkMGT]?\n    alg_spec ::= alg | alg#int\n    range_spec ::= alg_spec | alg_spec/alg_spec\n    spec ::= range_spec | range_spec:g_int:range_spec\n    NOTE: not all syntactically correct constructs are supported.\n\n    Examples:\n    \"xring\" == use one global ring reduction for all tensors\n    \"pscpu\" == use CPU at worker 0 to reduce all tensors\n    \"nccl\" == use NCCL to locally reduce all tensors.  Limited to 1 worker.\n    \"nccl/xring\" == locally (to one worker) reduce values using NCCL then ring reduce across workers.\n    \"pscpu:32k:xring\" == use pscpu algorithm for tensors of size up to 32kB, then xring for larger tensors.\n  --[no]allow_growth: whether to enable allow_growth in GPU_Options\n  --allreduce_merge_scope: Establish a name scope around this many gradients prior to creating the all-reduce operations. It may affect the ability of the backend to merge parallel ops.\n    (default: \'1\')\n    (an integer)\n  --autotune_threshold: The autotune threshold for the models\n    (an integer)\n  --backbone_model_path: Path to pretrained backbone model checkpoint. Pass None if not using a backbone model.\n  --batch_group_size: number of groups of batches processed in the image producer.\n    (default: \'1\')\n    (an integer)\n  --batch_size: batch size per compute device\n    (default: \'0\')\n    (an integer)\n  --[no]batchnorm_persistent: Enable/disable using the CUDNN_BATCHNORM_SPATIAL_PERSISTENT mode for batchnorm.\n    (default: \'true\')\n  --benchmark_log_dir: The directory to place the log files containing the results of benchmark. The logs are created by BenchmarkFileLogger. Requires the root of the Tensorflow models\n    repository to be in $PYTHTONPATH.\n  --benchmark_test_id: The unique test ID of the benchmark run. It could be the combination of key parameters. It is hardware independent and could be used compare the performance between\n    different test runs. This flag is designed for human consumption, and does not have any impact within the system.\n  --[no]cache_data: Enable use of a special datasets pipeline that reads a single TFRecord into memory and repeats it infinitely many times. The purpose of this flag is to make it possible to\n    write regression tests that are not bottlenecked by CNS throughput.\n    (default: \'false\')\n  --[no]compact_gradient_transfer: Compact gradientas much as possible for cross-device transfer and aggregation.\n    (default: \'true\')\n  --controller_host: optional controller host\n  --[no]cross_replica_sync: (no help available)\n    (default: \'true\')\n  --data_dir: Path to dataset in TFRecord format (aka Example protobufs). If not specified, synthetic data will be used.\n  --data_format: <NHWC|NCHW>: Data layout to use: NHWC (TF native) or NCHW (cuDNN native, requires GPU).\n    (default: \'NCHW\')\n  --data_name: Name of dataset: imagenet or cifar10. If not specified, it is automatically guessed based on data_dir.\n  --datasets_num_private_threads: Number of threads for a private threadpool created for all datasets computation. By default, we pick an appropriate number. If set to 0, we use the default\n    tf-Compute threads for dataset operations.\n    (an integer)\n  --datasets_prefetch_buffer_size: Prefetching op buffer size per compute device.\n    (default: \'1\')\n    (an integer)\n  --[no]datasets_use_prefetch: Enable use of prefetched datasets for input pipeline. This option is meaningless if use_datasets=False.\n    (default: \'true\')\n  --debugger: If set, use the TensorFlow debugger. If set to \"cli\", use the local CLI debugger. Otherwise, this must be in the form hostname:port (e.g., localhost:7007) in which case the\n    experimental TensorBoard debugger will be used\n  --device: <cpu|gpu|CPU|GPU>: Device to use for computation: cpu or gpu\n    (default: \'gpu\')\n  --display_every: Number of local steps after which progress is printed out\n    (default: \'10\')\n    (an integer)\n  --[no]distort_color_in_yiq: Distort color of input images in YIQ space.\n    (default: \'true\')\n  --[no]distortions: Enable/disable distortions during image preprocessing. These include bbox and color distortions.\n    (default: \'true\')\n  --[no]enable_optimizations: Whether to enable grappler and other optimizations.\n    (default: \'true\')\n  --[no]eval: whether use eval or benchmarking\n    (default: \'false\')\n  --eval_dir: Directory where to write eval event logs.\n    (default: \'/tmp/tf_cnn_benchmarks/eval\')\n  --eval_interval_secs: How often to run eval on saved checkpoints. Usually the same as save_model_secs from the corresponding training run. Pass 0 to eval only once.\n    (default: \'0\')\n    (an integer)\n  --[no]force_gpu_compatible: whether to enable force_gpu_compatible in GPU_Options\n    (default: \'false\')\n  --[no]forward_only: whether use forward-only or training for benchmarking\n    (default: \'false\')\n  --[no]fp16_enable_auto_loss_scale: If True and use_fp16 is True, automatically adjust the loss scale during training.\n    (default: \'false\')\n  --fp16_inc_loss_scale_every_n: If fp16 is enabled and fp16_enable_auto_loss_scale is True, increase the loss scale every n steps.\n    (default: \'1000\')\n    (an integer)\n  --fp16_loss_scale: If fp16 is enabled, the loss is multiplied by this amount right before gradients are computed, then each gradient is divided by this amount. Mathematically, this has no\n    effect, but it helps avoid fp16 underflow. Set to 1 to effectively disable.\n    (a number)\n  --[no]fp16_vars: If fp16 is enabled, also use fp16 for variables. If False, the variables are stored in fp32 and casted to fp16 when retrieved.  Recommended to leave as False.\n    (default: \'false\')\n  --[no]freeze_when_forward_only: whether to freeze the graph when in forward-only mode.\n    (default: \'false\')\n  --[no]fuse_decode_and_crop: Fuse decode_and_crop for image preprocessing.\n    (default: \'true\')\n  --gpu_indices: indices of worker GPUs in ring order\n    (default: \'\')\n  --gpu_memory_frac_for_testing: If non-zero, the fraction of GPU memory that will be used. Useful for testing the benchmark script, as this allows distributed mode to be run on a single\n    machine. For example, if there are two tasks, each can be allocated ~40 percent of the memory on a single machine\n    (default: \'0.0\')\n    (a number in the range [0.0, 1.0])\n  --gpu_thread_mode: Methods to assign GPU host work to threads. global: all GPUs and CPUs share the same global threads; gpu_private: a private threadpool for each GPU; gpu_shared: all GPUs\n    share the same threadpool.\n    (default: \'gpu_private\')\n  --gradient_clip: Gradient clipping magnitude. Disabled by default.\n    (a number)\n  --gradient_repacking: Use gradient repacking. Itcurrently only works with replicated mode. At the end ofof each step, it repacks the gradients for more efficientcross-device transportation.\n    A non-zero value specifiesthe number of split packs that will be formed.\n    (default: \'0\')\n    (a non-negative integer)\n  --graph_file: Write the model\'s graph definition to this file. Defaults to binary format unless filename ends in \"txt\".\n  --[no]hierarchical_copy: Use hierarchical copies. Currently only optimized for use on a DGX-1 with 8 GPUs and may perform poorly on other hardware. Requires --num_gpus > 1, and only\n    recommended when --num_gpus=8\n    (default: \'false\')\n  --horovod_device: Device to do Horovod all-reduce on: empty (default), cpu or gpu. Default with utilize GPU if Horovod was compiled with the HOROVOD_GPU_ALLREDUCE option, and CPU otherwise.\n    (default: \'\')\n  --init_learning_rate: Initial learning rate for training.\n    (a number)\n  --input_preprocessor: Name of input preprocessor. The list of supported input preprocessors are defined in preprocessing.py.\n    (default: \'default\')\n  --job_name: <ps|worker|controller|>: One of \"ps\", \"worker\", \"controller\", \"\".  Empty for local training\n    (default: \'\')\n  --kmp_affinity: Restricts execution of certain threads (virtual execution units) to a subset of the physical processing units in a multiprocessor computer.\n    (default: \'granularity=fine,verbose,compact,1,0\')\n  --kmp_blocktime: The time, in milliseconds, that a thread should wait, after completing the execution of a parallel region, before sleeping\n    (default: \'0\')\n    (an integer)\n  --kmp_settings: If set to 1, MKL settings will be printed.\n    (default: \'1\')\n    (an integer)\n  --learning_rate_decay_factor: Learning rate decay factor. Decay by this factor every `num_epochs_per_decay` epochs. If 0, learning rate does not decay.\n    (default: \'0.0\')\n    (a number)\n  --local_parameter_device: <cpu|gpu|CPU|GPU>: Device to use as parameter server: cpu or gpu. For distributed training, it can affect where caching of variables happens.\n    (default: \'gpu\')\n  --loss_type_to_report: <base_loss|total_loss>: Which type of loss to output and to write summaries for. The total loss includes L2 loss while the base loss does not. Note that the total\n    loss is always used while computing gradients during training if weight_decay > 0, but explicitly computing the total loss, instead of just computing its gradients, can have a performance\n    impact.\n    (default: \'total_loss\')\n  --max_ckpts_to_keep: Max number of checkpoints to keep.\n    (default: \'5\')\n    (an integer)\n  --minimum_learning_rate: The minimum learning rate. The learning rate will never decay past this value. Requires `learning_rate`, `num_epochs_per_decay` and `learning_rate_decay_factor` to\n    be set.\n    (default: \'0.0\')\n    (a number)\n  --[no]mkl: If true, set MKL environment variables.\n    (default: \'false\')\n  --model: Name of the model to run, the list of supported models are defined in models/model.py\n    (default: \'trivial\')\n  --momentum: Momentum for training.\n    (default: \'0.9\')\n    (a number)\n  --multi_device_iterator_max_buffer_size: Configuration parameter for the MultiDeviceIterator that  specifies the host side buffer size for each device.\n    (default: \'1\')\n    (an integer)\n  --network_topology: <dgx1|gcp_v100>: Network topology specifies the topology used to connect multiple devices. Network topology is used to decide the hierarchy to use for the\n    hierarchical_copy.\n    (default: \'NetworkTopology.DGX1\')\n  --num_batches: number of batches to run, excluding warmup. Defaults to 100\n    (an integer)\n  --num_epochs: number of epochs to run, excluding warmup. This and --num_batches cannot both be specified.\n    (a number)\n  --num_epochs_per_decay: Steps after which learning rate decays. If 0, the learning rate does not decay.\n    (default: \'0.0\')\n    (a number)\n  --num_gpus: the number of GPUs to run on\n    (default: \'1\')\n    (an integer)\n  --num_inter_threads: Number of threads to use for inter-op parallelism. If set to 0, the system will pick an appropriate number.\n    (default: \'0\')\n    (an integer)\n  --num_intra_threads: Number of threads to use for intra-op parallelism. If set to 0, the system will pick an appropriate number.\n    (an integer)\n  --num_learning_rate_warmup_epochs: Slowly increase to the initial learning rate in the first num_learning_rate_warmup_epochs linearly.\n    (default: \'0.0\')\n    (a number)\n  --num_warmup_batches: number of batches to run before timing\n    (an integer)\n  --optimizer: <momentum|sgd|rmsprop|adam>: Optimizer to use\n    (default: \'sgd\')\n  --partitioned_graph_file_prefix: If specified, after the graph has been partitioned and optimized, write out each partitioned graph to a file with the given prefix.\n  --per_gpu_thread_count: The number of threads to use for GPU. Only valid when gpu_thread_mode is not global.\n    (default: \'0\')\n    (an integer)\n  --piecewise_learning_rate_schedule: Specifies a piecewise learning rate schedule based on the number of epochs. This is the form LR0;E1;LR1;...;En;LRn, where each LRi is a learning rate and\n    each Ei is an epoch indexed from 0. The learning rate is LRi if the E(i-1) <= current_epoch < Ei. For example, if this paramater is 0.3;10;0.2;25;0.1, the learning rate is 0.3 for the\n    first 10 epochs, then is 0.2 for the next 15 epochs, then is 0.1 until training ends.\n  --[no]print_training_accuracy: whether to calculate and print training accuracy during training\n    (default: \'false\')\n  --ps_hosts: Comma-separated list of target hosts\n    (default: \'\')\n  --resize_method: Method for resizing input images: crop, nearest, bilinear, bicubic, area, or round_robin. The `crop` mode requires source images to be at least as large as the network\n    input size. The `round_robin` mode applies different resize methods based on position in a batch in a round-robin fashion. Other modes support any sizes and apply random bbox distortions\n    before resizing (even with distortions=False).\n    (default: \'bilinear\')\n  --rewriter_config: Config for graph optimizers, described as a RewriterConfig proto buffer.\n  --rmsprop_decay: Decay term for RMSProp.\n    (default: \'0.9\')\n    (a number)\n  --rmsprop_epsilon: Epsilon term for RMSProp.\n    (default: \'1.0\')\n    (a number)\n  --rmsprop_momentum: Momentum in RMSProp.\n    (default: \'0.9\')\n    (a number)\n  --save_model_secs: How often to save trained models. Pass 0 to disable checkpoints.\n    (default: \'0\')\n    (an integer)\n  --save_summaries_steps: How often to save summaries for trained models. Pass 0 to disable summaries.\n    (default: \'0\')\n    (an integer)\n  --server_protocol: protocol for servers\n    (default: \'grpc\')\n  --[no]single_l2_loss_op: If True, instead of using an L2 loss op per variable, concatenate the variables into a single tensor and do a single L2 loss on the concatenated tensor.\n    (default: \'false\')\n  --[no]staged_vars: whether the variables are staged from the main computation\n    (default: \'false\')\n  --summary_verbosity: Verbosity level for summary ops. level 0: disable any summary.\n    level 1: small and fast ops, e.g.: learning_rate, total_loss.\n    level 2: medium-cost ops, e.g. histogram of all gradients.\n    level 3: expensive ops: images and histogram of each gradient.\n    (default: \'0\')\n    (an integer)\n  --[no]sync_on_finish: Enable/disable whether the devices are synced after each step.\n    (default: \'false\')\n  --task_index: Index of task within the job\n    (default: \'0\')\n    (an integer)\n  --tf_random_seed: The TensorFlow random seed. Useful for debugging NaNs, as this can be set to various values to see if the NaNs depend on the seed.\n    (default: \'1234\')\n    (an integer)\n  --tfprof_file: If specified, write a tfprof ProfileProto to this file. The performance and other aspects of the model can then be analyzed with tfprof. See\n    https://github.com/tensorflow/tensorflow/blob/master/tensorflow/core/profiler/g3doc/command_line.md for more info on how to do this. The first 10 steps are profiled. Additionally, the top\n    20 most time consuming ops will be printed.\n    Note: profiling with tfprof is very slow, but most of the overhead is spent between steps. So, profiling results are more accurate than the slowdown would suggest.\n  --trace_file: Enable TensorFlow tracing and write trace to this file.\n    (default: \'\')\n  --train_dir: Path to session checkpoints. Pass None to disable saving checkpoint at the end.\n  --[no]use_chrome_trace_format: If True, the trace_file, if specified, will be in a Chrome trace format. If False, then it will be a StepStats raw proto.\n    (default: \'true\')\n  --[no]use_datasets: Enable use of datasets for input pipeline\n    (default: \'true\')\n  --[no]use_fp16: Use 16-bit floats for certain tensors instead of 32-bit floats. This is currently experimental.\n    (default: \'false\')\n  --[no]use_multi_device_iterator: If true, we use the MultiDeviceIterator for prefetching, which deterministically prefetches the data onto the various GPUs\n    (default: \'false\')\n  --[no]use_python32_barrier: When on, use threading.Barrier at Python 3.2.\n    (default: \'false\')\n  --[no]use_resource_vars: Use resource variables instead of normal variables. Resource variables are slower, but this option is useful for debugging their performance.\n    (default: \'false\')\n  --[no]use_tf_layers: If True, use tf.layers for neural network layers. This should not affect performance or accuracy in any way.\n    (default: \'true\')\n  --variable_consistency: <strong|relaxed>: The data consistency for trainable variables. With strong consistency, the variable always have the updates from previous step. With relaxed\n    consistency, all the updates will eventually show up in the variables. Likely one step behind.\n    (default: \'strong\')\n  --variable_update: <parameter_server|replicated|distributed_replicated|independent|distributed_all_reduce|collective_all_reduce|horovod>: The method for managing variables:\n    parameter_server, replicated, distributed_replicated, independent, distributed_all_reduce, collective_all_reduce, horovod\n    (default: \'parameter_server\')\n  --weight_decay: Weight decay factor for training.\n    (default: \'4e-05\')\n    (a number)\n  --[no]winograd_nonfused: Enable/disable using the Winograd non-fused algorithms.\n    (default: \'true\')\n  --worker_hosts: Comma-separated list of target hosts\n    (default: \'\')\n  --[no]xla: whether to enable XLA auto-jit compilation\n    (default: \'false\')\n\nabsl.flags:\n  --flagfile: Insert flag definitions from the given file into the command line.\n    (default: \'\')\n  --undefok: comma-separated list of flag names that it is okay to specify on the command line even if the program does not define a flag with that name.  IMPORTANT: flags in this list that\n    have arguments MUST use the --flag=value format.\n    (default: \'\')"
},

{
    "location": "workloads/ngraph/#",
    "page": "NGraph Models",
    "title": "NGraph Models",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/ngraph/#NGraph-Models-1",
    "page": "NGraph Models",
    "title": "NGraph Models",
    "category": "section",
    "text": "This (eventually) will be a collection of models implemented directly in nGraph, which will have high performance CPU models for inference and training."
},

{
    "location": "workloads/ngraph/#Usage-From-Launcher-1",
    "page": "NGraph Models",
    "title": "Usage From Launcher",
    "category": "section",
    "text": "Navigate to the Launcher/ directory and launch Julia withjulia --projectFrom inside Julia, to launch resnet 50 with a batchsize of 32, use the following command:julia> using Launcher\n\njulia> workload = Launcher.NGraph(args = (model = \"resnet50\", batchsize = 64, iterations = 100))Note that running for a larger number of iterations will likely yield better results.Valid Command Line Argumentsusage: ngraph.jl [--model MODEL] [--batchsize BATCHSIZE] [--mode MODE]\n                 [--iterations ITERATIONS] [-h]\n\noptional arguments:\n  --model MODEL         Define the model to use (default: \"resnet50\")\n  --batchsize BATCHSIZE\n                        The Batchsize to use (type: Int64, default:\n                        16)\n  --mode MODE           The mode to use [train or inference] (default:\n                        \"inference\")\n  --iterations ITERATIONS\n                        The number of calls to perform for\n                        benchmarking (type: Int64, default: 20)\n  -h, --help            show this help message and exit"
},

{
    "location": "workloads/ngraph/#Automatically-Applied-Arguments-1",
    "page": "NGraph Models",
    "title": "Automatically Applied Arguments",
    "category": "section",
    "text": "These are arguments automatically supplied by Launcher.--model: resnet50\n--mode: inference"
},

{
    "location": "workloads/ngraph/#Automatically-Applied-Environmental-Veriables-1",
    "page": "NGraph Models",
    "title": "Automatically Applied Environmental Veriables",
    "category": "section",
    "text": "Many of the nGraph parameters are controlled through environmental variables. The default supplied by Launcher are:NGRAPH_CODEGEN=1: Enable code generation of models. This typically has much tighter   runtimes than the nGraph interpreter, even if it\'s not necessarily faster.NOTE: Right now, the functionality to add more environmental variables does not exist, but will be exposed over time as the variables of interest are identified."
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
    "location": "workloads/slim/#Using-from-Launcher-1",
    "page": "Tensorflow Slim",
    "title": "Using from Launcher",
    "category": "section",
    "text": ""
},

{
    "location": "workloads/slim/#Launcher.Slim",
    "page": "Tensorflow Slim",
    "title": "Launcher.Slim",
    "category": "type",
    "text": "Struct representing parameters for launching the Tensorflow Official Resnet Model on the  Imagenet training set. Construct type using a key-word constructor Fields –––\n\nargs::NamedTuple - Arguments passed to the Keras Python script that creates and    trains Resnet.\ninteractive::Bool - Set to true to create a container that does not automatically run   Resnet when launched. Useful for debugging what\'s going on inside the container.\n\ncreate keywords\n\nmemory::Union{Nothing, Int} - The amount of memory to assign to this container. If   this value is nothing, the container will have access to all system memory.   Default: nothing.\ncpuSets = \"\" - The CPU sets on which to run the workload. Defaults to all processors.    Examples: \"0\", \"0-3\", \"1,3\".\n\n\n\n\n\n"
},

{
    "location": "workloads/slim/#Training-1",
    "page": "Tensorflow Slim",
    "title": "Training",
    "category": "section",
    "text": "Launcher.SlimNavigate to the Launcher/ directory, and launch julia with the commandjulia --projectFrom inside Julia, to launch resnet 50 with a batchsize of 32, use the following command:julia> using Launcher\n\njulia> workload = Launcher.Slim(args = (model_name = \"resnet_v1_50\", batchsize = 32))"
},

{
    "location": "workloads/slim/#Inference-1",
    "page": "Tensorflow Slim",
    "title": "Inference",
    "category": "section",
    "text": "In order to run inference throught the Slim models, you first need to obtain  pretrained model from the Slim repo: https://github.com/tensorflow/models/tree/master/research/slimRight click on the checkpoint for the model you want and copy the link. In the terminal, navigate toml-tools/workloads/slim/modelsand download the model withwget <paste-copied-link>Once the .tar file finished downloading, unpack it withtar -xvf <name-of-tarfile>To now run the trained model, you need to use the inference keyword for the Slim type, and pass the name of the checkpoint file you want to use.NOTE: The checkpoint_path path should be the correct path for the model_name model being used.NOTE: You just need to provide the name of the checkpoint file. As long as it live in workloads/slim/models/, Launcher will automatically manage it for you.An example commend for running inference on resnet_v1 is shown belowwork = Launcher.Slim(\n    inference = true, \n    args = (\n        checkpoint_path = \"resnet_v1_50.ckpt\", \n        model_name=\"resnet_v1_50\", \n        max_num_batches= 10\n    ),\n)Valid NetworksThe following is the list of valid inputs for the model_name argument:alexnet_v2\ncifarnet\noverfeat\nvgg_a\nvgg_16\nvgg_19\nvgg_416\ninception_v1\ninception_v2\ninception_v3\ninception_v4\ninception_resnet_v2\nlenet\nresnet_v1_50\nresnet_v1_101\nresnet_v1_152\nresnet_v1_200\nresnet_v2_50\nresnet_v2_101\nresnet_v2_152\nresnet_v2_200\nmobilenet_v1\nmobilenet_v1_075\nmobilenet_v1_050\nmobilenet_v1_025\nmobilenet_v2\nmobilenet_v2_140\nmobilenet_v2_035\nnasnet_cifar\nnasnet_mobile\nnasnet_large\npnasnet_large\npnasnet_mobile"
},

{
    "location": "workloads/slim/#Automatically-Applied-Arguments-1",
    "page": "Tensorflow Slim",
    "title": "Automatically Applied Arguments",
    "category": "section",
    "text": "These are arguments automatically supplied by Launcher.--dataset_dir: Binds the dataset at imagenet_tf_slim into /imagenet in the container.\n--dataset_name: Defaults to imagenet.\nclone_on_cpu: Defaults to true."
},

{
    "location": "workloads/slim/#Training-Script-Arguments:-1",
    "page": "Tensorflow Slim",
    "title": "Training Script Arguments:",
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
    "location": "datasets/imagenet/#TFBenchmarks-Preprocessing-1",
    "page": "Imagenet",
    "title": "TFBenchmarks Preprocessing",
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
