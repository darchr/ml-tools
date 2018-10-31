var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "ML-Tools",
    "title": "ML-Tools",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#ML-Tools-1",
    "page": "ML-Tools",
    "title": "ML-Tools",
    "category": "section",
    "text": "This repo contains a collection of tools, containers, and scripts for launching machine learning workloads in Docker containers and collecting statistics about the  containers."
},

{
    "location": "notebooks.html#",
    "page": "Notebooks",
    "title": "Notebooks",
    "category": "page",
    "text": ""
},

{
    "location": "notebooks.html#Notebooks-1",
    "page": "Notebooks",
    "title": "Notebooks",
    "category": "section",
    "text": "The notebooks in this repo contain plots and run scripts to generate the data for those  plots. The contents of the notebooks are summarized here and contain links to the rendered notebooks are included.In general, each directory contains a notebook and a collection of scripts. Since sudo access is needed to run MemSnoop, these scripts are stand-alone. Note that these scripts should be run before the notebooks if trying to recreate the plots."
},

{
    "location": "notebooks.html#[Basic-Analysis](https://github.com/darchr/ml-notebooks/blob/master/basic_analysis/basic_analysis.ipynb)-1",
    "page": "Notebooks",
    "title": "Basic Analysis",
    "category": "section",
    "text": "Basic analysis of the memory usage during the training of a simple CNN on a single CPU. The sampling window was 0.2 seconds. That is, the sampling procedure went something like this:Mark all the applications pages as idle.\nRun application for 0.2 seconds\nPause application\nDetermine which pages are active and update data structures.\nRepeatPlots included in this section:WSS estimation for a single threaded process.\nReuse distance analysis.\nVerification that Docker and Python are not interfering with the measurements.\nHeatmap plots visualizing the memory access patterns to the Python heap and for the whole  application during 1 epoch of training."
},

{
    "location": "notebooks.html#[CPU-Analysis](https://github.com/darchr/ml-notebooks/blob/master/cpu_analysis/cpu_analysis.ipynb)-1",
    "page": "Notebooks",
    "title": "CPU Analysis",
    "category": "section",
    "text": "Plots and some analysis of how the memory requirements and training speed for 2 epochs of  training scale as the number of available processors is increased."
},

{
    "location": "notebooks.html#[Batchsize](https://github.com/darchr/ml-notebooks/blob/master/batchsize/batchsizes.ipynb)-1",
    "page": "Notebooks",
    "title": "Batchsize",
    "category": "section",
    "text": "Data on how WSS and Reuse Distance vary with training batch size. Parameters of experiment:* Small CNN on Cifar10 dataset\n* Single thread\n* Unlimited memory\n* 0.5 second sampletime\n* 1 epoch of training\n* Batchsizes: 16, 32, 64, 128, 256, 512, 1024I\'m not entirely sure what that data means yet ..."
},

{
    "location": "notebooks.html#[Filters](https://github.com/darchr/ml-notebooks/blob/master/filters/filters.ipynb)-1",
    "page": "Notebooks",
    "title": "Filters",
    "category": "section",
    "text": "The goal of this experiment is to see if we can filter out some types of memory during the trace without significantly affecting the results. Filtering out some regions of memory can speed up the idle page tracking process and reduce the memory footprint of the snooper.In particular, I explore filtering out Virtual Memory Areas (VMAs) that are* Executable\n* Neither readable nor writable\n* Smaller than 4 pagesConclusion - It\'s probably okay to do this. However, I need to try this on non single threaded models just in case."
},

{
    "location": "notebooks.html#[Sample-Time](https://github.com/darchr/ml-notebooks/blob/master/wss_time/wss_estimate_sensitivity.ipynb)-1",
    "page": "Notebooks",
    "title": "Sample Time",
    "category": "section",
    "text": "Experiment to investigate how sensitive our estimates of WSS and Reuse Distance are to the sample time. Parameters of the experiment:* Small CNN on Cifar dataset\n* Both single threaded and with 12 threads\n* Sample times of 0.2, 0.5, 1, 2, 4, and 8 seconds\n* Batch size of 128\n* Training for 1 epoch"
},

{
    "location": "docker.html#",
    "page": "Docker",
    "title": "Docker",
    "category": "page",
    "text": ""
},

{
    "location": "docker.html#Docker-1",
    "page": "Docker",
    "title": "Docker",
    "category": "section",
    "text": "Docker images are used to create reproducible environments and to more easily enable tricks like CPU and memory limiting."
},

{
    "location": "tensorflow.html#",
    "page": "Tensorflow",
    "title": "Tensorflow",
    "category": "page",
    "text": ""
},

{
    "location": "tensorflow.html#Tensorflow-1",
    "page": "Tensorflow",
    "title": "Tensorflow",
    "category": "section",
    "text": "We will use Tensorflow as one of the ML frameworks for  testing. Since the standard distribution for Tensorflow is not compiled with AVX2  instructions, I compiled Tensorflow from source on amarillo. The directory tf-compile/ has the relevant files for how this is done.The Docker Hub where the most current version of this container lives is here: https://hub.docker.com/r/darchr/tf-compiled-base/. This repo will be kept  up-to-date as I make needed changes to the container.I\'m using the official tensorflow docker approach to compile and build the pip package for tensor flow.https://www.tensorflow.org/install/source\nhttps://www.tensorflow.org/install/dockerHelpful post talking about docker permissions https://denibertovic.com/posts/handling-permissions-with-docker-volumes/"
},

{
    "location": "tensorflow.html#Compilation-Overview-1",
    "page": "Tensorflow",
    "title": "Compilation Overview",
    "category": "section",
    "text": "Containers will be build incrementally, starting with darchr/tf-compiled-base, which is the base image containing Tensorflow that has been compiled on amarillo. Compiling Tensorflow is important because the default Tensorflow binary is not compiled to use AVX2 instructions. Using the very scientific \"eyeballing\" approach, this compiled version of Tensorflow runs ~60% faster.Other containers that use Tensorflow can be build from darchr/tf-compiled/base."
},

{
    "location": "tensorflow.html#Building-tf-compiled-base-1",
    "page": "Tensorflow",
    "title": "Building tf-compiled-base",
    "category": "section",
    "text": "As a high level overview, we use an official Tensorflow docker containers to build a  Python 3.5 \"wheel\" (package). We then use a Python 3.5.6 docker container as a base to  install the compiled tensorflow wheel."
},

{
    "location": "tensorflow.html#Compiling-Tensorflow-1",
    "page": "Tensorflow",
    "title": "Compiling Tensorflow",
    "category": "section",
    "text": "Pull the docker container with the source code:docker pull tensorflow/tensorflow:1.10.0-devel-py3Launch the container withdocker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS=\"$(id -u):$(id -g)\" tensorflow/tensorflow:1.10.0-devel-py3 bashThis does the following:Opens the container in the /tensorflow directory, which contains the tensorflow source   code\nMounts the current directory into the /mnt directory in the container. This allows the   .whl build to be dropped in the PWD after compilation.Inside the container, rungit pullto pull the latest copy of the tensorflow source. Then configure the build with./configureSettings used:Python Location: default\nPython Library Path: default\njemalloc support: Y\nGoogle cloud platform support: n\nHadoop file system support: n\nAmazon AWS platform support: n\nApache Kafka Platform support: n\nXLA Jis support: N\nGDR support: N\nVERBs support: N\nnGraph support: N\nOpenCL SYCL support: N\nCUDA support: N\nFresh clang release: N\nMPI support: N\nOptimization flags: default\nInteractively configure ./WORKSPACE: NSteps to build:bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package\n./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt\nchown $HOST_PERMS /mnt/tensorflow-1.10.1-cp35-cp35m-linux_x86_64.whlNote, compilation takes quite a while, so be patient. If running on amarillo, enjoy the 96 thread awesomeness."
},

{
    "location": "tensorflow.html#Summary-1",
    "page": "Tensorflow",
    "title": "Summary",
    "category": "section",
    "text": "docker pull tensorflow/tensorflow:nightly-devel-py3\ndocker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS=\"$(id -u):$(id -g)\" tensorflow/tensorflow:nightly-devel-py3 bash\n# inside container\ngit pull\n./configure # Look at options above\nbazel build --config=opt //tensorflow/tools/pip_package:build_pip_package\n./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt\nchown $HOST_PERMS /mnt/tensorflow-1.10.1-cp35-cp35m-linux_x86_64.whl"
},

{
    "location": "tensorflow.html#Building-the-Docker-Image-1",
    "page": "Tensorflow",
    "title": "Building the Docker Image",
    "category": "section",
    "text": "With the .whl for tensorflow build, we can build a new Docker container with this  installed. For this step, move tensorflow-...-.whl into the tf-compiled-base/  directory. Then, run the shell script:./build.sh tensorflow-1.10.1-cp35-cm35m-linux_x86_64.whlFinally, if necessary, push the image to the darchr docker hub viadocker push darchr/tf-compiled-base"
},

{
    "location": "tensorflow.html#Details-1",
    "page": "Tensorflow",
    "title": "Details",
    "category": "section",
    "text": "Annoyingly, the .whl created in the previous step only works with Python 3.5. I tried  hacking it by changing the name (cp35-cp35m -> cp36-cp36m), but installation with pip  failed. This means that we need a working copy of Python 3.5 in order to run this.  Fortunately, the Python foundation supplies Debian (I think ... or Ubuntu) based containers for past Python versions. We can use this as a starting point for our Dockerfile.Permissions with the docker containers was becoming a bit of a nightmare. I finally found a solution that works by installing gosu:https://github.com/tianon/gosu\nhttps://denibertovic.com/posts/handling-permissions-with-docker-volumes/Essentially, a dummy account user is created that does not have root privileges, but we can still create directories within the docker containers."
},

{
    "location": "tensorflow.html#Building-tf-keras-1",
    "page": "Tensorflow",
    "title": "Building tf-keras",
    "category": "section",
    "text": "Just run the build script with:./build.sh"
},

{
    "location": "ubuntu.html#",
    "page": "Ubuntu Workloads",
    "title": "Ubuntu Workloads",
    "category": "page",
    "text": ""
},

{
    "location": "ubuntu.html#Ubuntu-Workloads-1",
    "page": "Ubuntu Workloads",
    "title": "Ubuntu Workloads",
    "category": "section",
    "text": "Workloads that run under the official ubuntu docker image."
},

{
    "location": "ubuntu.html#Launcher.TestWorkload",
    "page": "Ubuntu Workloads",
    "title": "Launcher.TestWorkload",
    "category": "type",
    "text": "Launch the test workload in a ubuntu image.\n\nFields\n\nnone\n\ncreate Keyword Arguments\n\nnone\n\n\n\n\n\n"
},

{
    "location": "ubuntu.html#Test-1",
    "page": "Ubuntu Workloads",
    "title": "Test",
    "category": "section",
    "text": "A simple shell script that prints a message, sleeps for a few seconds, prints another message and exits. The point of this workload is to provide a simple and quick to run test to decrease debugging time.File name: /workloads/ubuntu/sleep.sh\nContainer entry point: /home/startup/sleep.shLauncher DocsLauncher.TestWorkload"
},

{
    "location": "keras.html#",
    "page": "Keras Models",
    "title": "Keras Models",
    "category": "page",
    "text": ""
},

{
    "location": "keras.html#Keras-Models-1",
    "page": "Keras Models",
    "title": "Keras Models",
    "category": "section",
    "text": ""
},

{
    "location": "keras.html#Launcher.CifarCnn",
    "page": "Keras Models",
    "title": "Launcher.CifarCnn",
    "category": "type",
    "text": "Workload object for the Keras Cifar10 cnn. Build type using keyword constructors.\n\nFields\n\nargs :: NamedTuple - Arguments to pass to the startup script (see docs).    Default: NamedTuple()\ninteractive :: Bool - If set to true, the container will launch into /bin/bash   instead of Python. Used for debugging the container. Default: false.\n\ncreate keywords\n\ncpuSets = \"\" - The CPU sets on which to run the workload. Defaults to all processors.    Examples: \"0\", \"0-3\", \"1,3\".\n\n\n\n\n\n"
},

{
    "location": "keras.html#Cifar-Cnn-1",
    "page": "Keras Models",
    "title": "Cifar Cnn",
    "category": "section",
    "text": "A simple CNN for training on the cifar-10 dataset. This model is small enough that a couple epochs of training takes a reasonably short amount of time, even when snooping memory.File name: /workloads/keras/cifar_cnn.py\nContainer entry point: /home/startup/cifar_cnn.py\nDataset: cifar-10-batches-py.tar.gz    (https://www.cs.toronto.edu/~kriz/cifar-10-python.tar.gz)\nEndpoint for dataset in container: /home/user/.keras/datasets/cifar-10-batches-py.tar.gz.   If dataset doesn\'t exist, it will automatically be downloaded. However, this can take   a while and is a bit rude to the site hosting the dataset.\nScript Arguments:\n--batchsize [size] : Configure the batch size for training.\n--epochs [n] : Train for n epochs\n--abort : Import the keras and tensorflow libraries and then exit. Used for    testing the overhead of code loading.Launcher Docs:Launcher.CifarCnn"
},

{
    "location": "keras.html#Resnet-Cnn-1",
    "page": "Keras Models",
    "title": "Resnet Cnn",
    "category": "section",
    "text": "TODO"
},

{
    "location": "launcher.html#",
    "page": "Launcher",
    "title": "Launcher",
    "category": "page",
    "text": ""
},

{
    "location": "launcher.html#Launcher-1",
    "page": "Launcher",
    "title": "Launcher",
    "category": "section",
    "text": "Launcher is the Julia package (sorry, I really, really like writing Julia code) for handling the launching of containers, aggregation of results, binding containers with relevant datasets, and generally making sure everything is working correctly. Documentation for this package can be found in this section.The functionality provided by this model is very straightforward and can probably be ported to another language if needed.Note that Launcher is built on top of two other packages:DockerX - Package for interacting with   the Docker API.\nMemSnoop - Package for tracking the memory   usage patterns of applications on the Linux operating system.These two packages are still works in progress and documentation on them is forthcoming. However, I plan on registering at least DockerX and probably MemSnoop as well as soon as I take the time to get them production ready."
},

{
    "location": "launcher.html#Base.run",
    "page": "Launcher",
    "title": "Base.run",
    "category": "function",
    "text": "run([f::Function], work::AbstractWorkload; kw...)\n\nCreate and launch a container from work with\n\ncontainer = create(work; kw...)\n\nStart the container and then call f(container). If f is not given, then attach to the container\'s stdout.\n\nThis function ensures that containers are stopped and cleaned up in case something goes wrong.\n\nExamples\n\nUsing Julia\'s do syntax to perform a stack based analysis\n\ntracker = run(TestWorkload()) do container\n    trackstack(getpid(container))\nend\n\n\n\n\n\n"
},

{
    "location": "launcher.html#Launcher.AbstractWorkload",
    "page": "Launcher",
    "title": "Launcher.AbstractWorkload",
    "category": "type",
    "text": "Abstract supertype for workloads. Concrete subtypes should be implemented for each workload desired for analysis.\n\n\n\n\n\n"
},

{
    "location": "launcher.html#Launcher.startfile",
    "page": "Launcher",
    "title": "Launcher.startfile",
    "category": "function",
    "text": "startfile(work::AbstractWorkload, ::Type{OnHost}) -> String\n\nReturn the path of the entrypoint file of work on the host machine.\n\nstartfile(work::AbstractWorkload, ::Type{OnContainer}) -> String\n\nReturn the path of the entrypoint file of work on the Docker Container.\n\n\n\n\n\n"
},

{
    "location": "launcher.html#Launcher.runcommand",
    "page": "Launcher",
    "title": "Launcher.runcommand",
    "category": "function",
    "text": "runcommand(work::AbstractWorkload) -> Cmd\n\nReturn the Docker Container entry command for work.\n\n\n\n\n\n"
},

{
    "location": "launcher.html#Launcher.create",
    "page": "Launcher",
    "title": "Launcher.create",
    "category": "function",
    "text": "create(work::AbstractWorkload; kw...) -> Container\n\nCreate a Docker Container for work, with optional keyword arguments. Concrete subtypes of AbstractWorkload must define this method and perform all the necessary steps to creating the Container. Note that the container should just be created by a call to DockerX.create_container, and not actually started.\n\nKeyword arguments supported by work should be included in that types documentation.\n\n\n\n\n\n"
},

{
    "location": "launcher.html#Temporary-Documentation-1",
    "page": "Launcher",
    "title": "Temporary Documentation",
    "category": "section",
    "text": "Launcher.run\nLauncher.AbstractWorkload\nLauncher.startfile\nLauncher.runcommand\nLauncher.create"
},

]}
