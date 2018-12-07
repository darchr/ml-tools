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
    "location": "manifest/#[DockerX](https://github.com/hildebrandmw/DockerX.jl)-1",
    "page": "Manifest",
    "title": "DockerX",
    "category": "section",
    "text": "Julia interface to the Docker API for managing containers and gathering metrics. This  package is based on the original Docker package, but updated to serve our own needs. I\'ve also added CI to the build process."
},

{
    "location": "manifest/#TODO-List-(Low-Priority)-1",
    "page": "Manifest",
    "title": "TODO List (Low Priority)",
    "category": "section",
    "text": "Add documentation of features in README. No need for auto docs.\nEventually, I would like to get this merged with the original Docker package, which would   likely involve:\nForking the original Docker repo.\nMigrating the code in DockerX to the forked Docker repo.\nIssue a string of pull requests to get the functionality migrated.\nThe Docker daemon by default listens on a Unix socket. In order to get the    HTTP to talk to a Unix socket, I had to extend   some of the methods in HTTP. Contributing this code to HTTP would be a good    contribution I think."
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
    "location": "manifest/#[MemSnoop](https://github.com/hildebrandmw/MemSnoop.jl)-1",
    "page": "Manifest",
    "title": "MemSnoop",
    "category": "section",
    "text": "Snooping routines to gather metrics on running programs. Includes the following analyses:Idle page tracking\nHardware performance counter tracking through PAPI.One of the big goals of this package is to reduce the number of third party dependencies as much as possible since Idle Page Tracking requires Julia to be run as root."
},

{
    "location": "manifest/#TODO-List-(Med-Priority)-1",
    "page": "Manifest",
    "title": "TODO List (Med Priority)",
    "category": "section",
    "text": "Add support for monitoring multiple processes.\nMove suitable code from SnoopAnalyzer    into MemSnoop.\nHave other people use this package to find bugs and improve documentation."
},

{
    "location": "manifest/#[SnoopAnalyzer](https://github.com/hildebrandmw/SnoopAnalyzer.jl)-1",
    "page": "Manifest",
    "title": "SnoopAnalyzer",
    "category": "section",
    "text": "Analysis routines for MemSnoop that require external dependencies. This will probably  eventually just be for plotting plus some other misc stuff."
},

{
    "location": "manifest/#TODO-List-(Low-Priority)-3",
    "page": "Manifest",
    "title": "TODO List (Low Priority)",
    "category": "section",
    "text": "Documentation\nSee when migration to Makie is suitable.    Theoretically, the plotting recipe system for Makie might not rely on a macro, so    plotting recipes for MemSnoop might be able to be implemented straight in MemSnoop    without adding any dependencies."
},

{
    "location": "manifest/#[ml-notebooks-(private)](https://github.com/darchr/ml-notebooks)-1",
    "page": "Manifest",
    "title": "ml-notebooks (private)",
    "category": "section",
    "text": "Jupyter notebooks and scripts for research."
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
    "location": "notebooks/#",
    "page": "Notebooks",
    "title": "Notebooks",
    "category": "page",
    "text": ""
},

{
    "location": "notebooks/#Notebooks-1",
    "page": "Notebooks",
    "title": "Notebooks",
    "category": "section",
    "text": "The notebooks in this repo contain plots and run scripts to generate the data for those  plots. The contents of the notebooks are summarized here and contain links to the rendered notebooks are included.In general, each directory contains a notebook and a collection of scripts. Since sudo access is needed to run MemSnoop, these scripts are stand-alone. Note that these scripts should be run before the notebooks if trying to recreate the plots."
},

{
    "location": "notebooks/#[Basic-Analysis](https://github.com/darchr/ml-notebooks/blob/master/basic_analysis/basic_analysis.ipynb)-1",
    "page": "Notebooks",
    "title": "Basic Analysis",
    "category": "section",
    "text": "Basic analysis of the memory usage during the training of a simple CNN on a single CPU. The sampling window was 0.2 seconds. That is, the sampling procedure went something like this:Mark all the applications pages as idle.\nRun application for 0.2 seconds\nPause application\nDetermine which pages are active and update data structures.\nRepeatPlots included in this section:WSS estimation for a single threaded process.\nReuse distance analysis.\nVerification that Docker and Python are not interfering with the measurements.\nHeatmap plots visualizing the memory access patterns to the Python heap and for the whole  application during 1 epoch of training."
},

{
    "location": "notebooks/#[ResNet50-in-ImageNet](https://github.com/darchr/ml-notebooks/blob/master/resnet_imagenet/Resnet.ipynb)-1",
    "page": "Notebooks",
    "title": "ResNet50 in ImageNet",
    "category": "section",
    "text": "Initial look at the memory usage of a large model on ImageNet. This sample data was trained on ResNet50 using a single CPU (yes, very slow). Sampling window was 0.1 seconds.The highlight of this is that we can see the forward and backward passes in memory."
},

{
    "location": "notebooks/#[CPU-Analysis](https://github.com/darchr/ml-notebooks/blob/master/cpu_analysis/cpu_analysis.ipynb)-1",
    "page": "Notebooks",
    "title": "CPU Analysis",
    "category": "section",
    "text": "Plots and some analysis of how the memory requirements and training speed for 2 epochs of  training scale as the number of available processors is increased."
},

{
    "location": "notebooks/#[Batchsize](https://github.com/darchr/ml-notebooks/blob/master/batchsize/batchsizes.ipynb)-1",
    "page": "Notebooks",
    "title": "Batchsize",
    "category": "section",
    "text": "Data on how WSS and Reuse Distance vary with training batch size. Parameters of experiment:* Small CNN on Cifar10 dataset\n* Single thread\n* Unlimited memory\n* 0.5 second sampletime\n* 1 epoch of training\n* Batchsizes: 16, 32, 64, 128, 256, 512, 1024I\'m not entirely sure what that data means yet ..."
},

{
    "location": "notebooks/#[Filters](https://github.com/darchr/ml-notebooks/blob/master/filters/filters.ipynb)-1",
    "page": "Notebooks",
    "title": "Filters",
    "category": "section",
    "text": "The goal of this experiment is to see if we can filter out some types of memory during the trace without significantly affecting the results. Filtering out some regions of memory can speed up the idle page tracking process and reduce the memory footprint of the snooper.In particular, I explore filtering out Virtual Memory Areas (VMAs) that are* Executable\n* Neither readable nor writable\n* Smaller than 4 pagesConclusion - It\'s probably okay to do this. However, I need to try this on non single threaded models just in case."
},

{
    "location": "notebooks/#[Sample-Time](https://github.com/darchr/ml-notebooks/blob/master/sampletime/sampletime.ipynb)-1",
    "page": "Notebooks",
    "title": "Sample Time",
    "category": "section",
    "text": "Experiment to investigate how sensitive our estimates of WSS and Reuse Distance are to the sample time. Parameters of the experiment:* Small CNN on Cifar dataset\n* Both single threaded and with 12 threads\n* Sample times of 0.2, 0.5, 1, 2, 4, and 8 seconds\n* Batch size of 128\n* Training for 1 epoch"
},

{
    "location": "docker/docker/#",
    "page": "Docker",
    "title": "Docker",
    "category": "page",
    "text": ""
},

{
    "location": "docker/docker/#Docker-1",
    "page": "Docker",
    "title": "Docker",
    "category": "section",
    "text": "Docker images are used to create reproducible environments and to more easily enable tricks like CPU and memory limiting."
},

{
    "location": "docker/tensorflow/#",
    "page": "Tensorflow CPU",
    "title": "Tensorflow CPU",
    "category": "page",
    "text": ""
},

{
    "location": "docker/tensorflow/#Tensorflow-CPU-1",
    "page": "Tensorflow CPU",
    "title": "Tensorflow CPU",
    "category": "section",
    "text": "We will use Tensorflow as one of the ML frameworks for  testing. Since the standard distribution for Tensorflow is not compiled with AVX2  instructions, I compiled Tensorflow from source on amarillo. The directory tf-compile/ has the relevant files for how this is done.The Docker Hub where the most current version of this container lives is here: https://hub.docker.com/r/darchr/tf-compiled-base/. This repo will be kept  up-to-date as I make needed changes to the container.I\'m using the official tensorflow docker approach to compile and build the pip package for tensor flow.https://www.tensorflow.org/install/source\nhttps://www.tensorflow.org/install/dockerHelpful post talking about docker permissions https://denibertovic.com/posts/handling-permissions-with-docker-volumes/"
},

{
    "location": "docker/tensorflow/#Compilation-Overview-1",
    "page": "Tensorflow CPU",
    "title": "Compilation Overview",
    "category": "section",
    "text": "Containers will be build incrementally, starting with darchr/tf-compiled-base, which is the base image containing Tensorflow that has been compiled on amarillo. Compiling Tensorflow is important because the default Tensorflow binary is not compiled to use AVX2 instructions. Using the very scientific \"eyeballing\" approach, this compiled version of Tensorflow runs ~60% faster.Other containers that use Tensorflow can be build from darchr/tf-compiled/base."
},

{
    "location": "docker/tensorflow/#darchr/tf-compiled-base-1",
    "page": "Tensorflow CPU",
    "title": "darchr/tf-compiled-base",
    "category": "section",
    "text": "As a high level overview, we use an official Tensorflow docker containers to build a  Python 3.5 \"wheel\" (package). We then use a Python 3.5.6 docker container as a base to  install the compiled tensorflow wheel."
},

{
    "location": "docker/tensorflow/#Compiling-Tensorflow-1",
    "page": "Tensorflow CPU",
    "title": "Compiling Tensorflow",
    "category": "section",
    "text": "Pull the docker container with the source code:docker pull tensorflow/tensorflow:1.10.0-devel-py3Launch the container withdocker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS=\"$(id -u):$(id -g)\" tensorflow/tensorflow:1.10.0-devel-py3 bashThis does the following:Opens the container in the /tensorflow directory, which contains the tensorflow source   code\nMounts the current directory into the /mnt directory in the container. This allows the   .whl build to be dropped in the PWD after compilation.Inside the container, rungit pullto pull the latest copy of the tensorflow source. Then configure the build with./configureSettings used:Python Location: default\nPython Library Path: default\njemalloc support: Y\nGoogle cloud platform support: n\nHadoop file system support: n\nAmazon AWS platform support: n\nApache Kafka Platform support: n\nXLA Jis support: N\nGDR support: N\nVERBs support: N\nnGraph support: N\nOpenCL SYCL support: N\nCUDA support: N\nFresh clang release: N\nMPI support: N\nOptimization flags: default\nInteractively configure ./WORKSPACE: NSteps to build:bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package\n./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt\nchown $HOST_PERMS /mnt/tensorflow-1.10.1-cp35-cp35m-linux_x86_64.whlNote, compilation takes quite a while, so be patient. If running on amarillo, enjoy the 96 thread awesomeness."
},

{
    "location": "docker/tensorflow/#Summary-1",
    "page": "Tensorflow CPU",
    "title": "Summary",
    "category": "section",
    "text": "docker pull tensorflow/tensorflow:nightly-devel-py3\ndocker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS=\"$(id -u):$(id -g)\" tensorflow/tensorflow:nightly-devel-py3 bash\n# inside container\ngit pull\n./configure # Look at options above\nbazel build --config=opt //tensorflow/tools/pip_package:build_pip_package\n./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt\nchown $HOST_PERMS /mnt/tensorflow-1.10.1-cp35-cp35m-linux_x86_64.whl"
},

{
    "location": "docker/tensorflow/#Building-the-Docker-Image-1",
    "page": "Tensorflow CPU",
    "title": "Building the Docker Image",
    "category": "section",
    "text": "With the .whl for tensorflow build, we can build a new Docker container with this  installed. For this step, move tensorflow-...-.whl into the tf-compiled-base/  directory. Then, run the shell script:./build.sh tensorflow-1.10.1-cp35-cm35m-linux_x86_64.whlFinally, if necessary, push the image to the darchr docker hub viadocker push darchr/tf-compiled-base"
},

{
    "location": "docker/tensorflow/#Details-1",
    "page": "Tensorflow CPU",
    "title": "Details",
    "category": "section",
    "text": "Annoyingly, the .whl created in the previous step only works with Python 3.5. I tried  hacking it by changing the name (cp35-cp35m -> cp36-cp36m), but installation with pip  failed. This means that we need a working copy of Python 3.5 in order to run this.  Fortunately, the Python foundation supplies Debian (I think ... or Ubuntu) based containers for past Python versions. We can use this as a starting point for our Dockerfile.Permissions with the docker containers was becoming a bit of a nightmare. I finally found a solution that works by installing gosu:https://github.com/tianon/gosu\nhttps://denibertovic.com/posts/handling-permissions-with-docker-volumes/Essentially, a dummy account user is created that does not have root privileges, but we can still create directories within the docker containers."
},

{
    "location": "docker/tensorflow/#darchr/tf-keras-1",
    "page": "Tensorflow CPU",
    "title": "darchr/tf-keras",
    "category": "section",
    "text": "Container built from darchr/tf-compiled-base with the keras package installed.Just run the build script with:./build.sh"
},

{
    "location": "docker/tensorflow/#darchr/tf-official-models-1",
    "page": "Tensorflow CPU",
    "title": "darchr/tf-official-models",
    "category": "section",
    "text": "Container build from darchr/tf-compiled-base. Installs the dependencies required to run the official models for Tensorflow.Building is simple, just run./build.sh"
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
    "text": ""
},

{
    "location": "datasets/imagenet/#Getting-the-Datasets-1",
    "page": "Imagenet",
    "title": "Getting the Datasets",
    "category": "section",
    "text": "Theoretically, you can download the original 2012 Imagenet images from  http://image-net.org/download-images by first registering. However, when I tried that, I never received an email confirming my registration and thus allowing me to download. I had to resort to ... other means.In the process of searching for where to download, I came across some comments that the  Imagenet2012 database had moved to a new home. However, when writing up this documentation, I couldn\'t find that reference nor the new home.In conclusion, it seems that getting the dataset is significantly less straightforward than it should be. However, it is possible to find the dataset eventually."
},

{
    "location": "datasets/imagenet/#Using-Imagenet-in-Tensorflow-1",
    "page": "Imagenet",
    "title": "Using Imagenet in Tensorflow",
    "category": "section",
    "text": "The training and validation .tar files need to be converted into something called a  TFRecord format (something used by Tensorflow I guess). This flow assumes that you have the datasets downloaded and stored in a path /path-to-datasets/. Some helpful links are provided:Documentation on how to get the official ResNet tensorflow models working on the   Image net data: https://github.com/tensorflow/models/tree/master/official/resnet\nDocumentation and script for converting the Imagenet .tar files into the form desired   by Tensorflow: https://github.com/tensorflow/tpu/tree/master/tools/datasets#imagenet_to_gcspy\nThe Python script that does the conversion: https://github.com/tensorflow/tpu/blob/master/tools/datasets/imagenet_to_gcs.pyThis info should all be incorporated into the build script build.sh. To run it, just  execute./build.sh /path-to-tar-filesThis will create the folders/path-to-tar-files/train\n/path-to-tar-files/validationand unpack the tar files into these respective folders. The original tar files will be left alone, so make sure you have around 300G of extra free space when you do this, otherwise  you\'re gonna have a bad day.After unpacking, the build script will execute the imagenet_to_gcs.py script to do the actual conversion.Be aware that dataset conversion can take a long time. You probably want to run the build script in a tmux shell or something so you can go have a coffee.Note that the build script will launch an docker instance of darchr/tf-compiled-base  because the Python script needs Tensorflow to run. Once the script finishes, you should be good to go."
},

{
    "location": "datasets/imagenet/#Changes-made-to-imagenet_to_gcs.py-1",
    "page": "Imagenet",
    "title": "Changes made to imagenet_to_gcs.py",
    "category": "section",
    "text": "I had to make several changes for Python 2 to Python 3 compatibility. (Seriously folks,  can\'t we all just agree to use Python 3??)Line 58: Commented out the import google.cloud ... line because we\'re not uploading    anything to the google cloud and I don\'t want to install that package.\nLines 177, 179: Suffixed string literals with \'\'.encode() to tell python that these    should by byte collections.\nLines 187, 189: Add .encode to several strings to _bytes_feature doesn\'t complain.\nLine 282: Change the \'r\' option in reading to \'rb\'. Avoid trying to reinterpret image   data as utf-8, which will definitely not work.\nLine 370: A Python range object is used and then shuffled. However, in Python3, ranges   have become lazy and thus cannot be shuffled. I changed this by explicitly converting   the range to a list, forcing materialization of the whole range."
},

{
    "location": "datasets/slim/#",
    "page": "Tensorflow Slim",
    "title": "Tensorflow Slim",
    "category": "page",
    "text": ""
},

{
    "location": "datasets/slim/#Tensorflow-Slim-1",
    "page": "Tensorflow Slim",
    "title": "Tensorflow Slim",
    "category": "section",
    "text": ""
},

{
    "location": "datasets/slim/#Preparation-steps-(don\'t-need-to-repeat)-1",
    "page": "Tensorflow Slim",
    "title": "Preparation steps (don\'t need to repeat)",
    "category": "section",
    "text": "The code in this repo is taken from the build process that comes in the slim project. However, I\'ve modified it so it works without having to go through Bazel (I don\'t really know why that was used in the first place) and also updated it so it works with Python3."
},

{
    "location": "datasets/slim/#Changes-made-to-build-1",
    "page": "Tensorflow Slim",
    "title": "Changes made to build",
    "category": "section",
    "text": "download_and_convert_imagenet.sh\nRemoved some build comments that are no longer relevant.\nLine 59: Change path for WORK_DIR since we\'re no longer doing the Bazel style   build.\nLine 104: Change path to build_iamgenet_data.py.\nLine 108: Put python3 in front of script invocation. Get around executable   permission errors.\ndatasets/build_imagenet_data.py\nLines 213, 216, 217, and 224: Suffix .encode() on string arguments to pass them   as bytes to _bytes_feature.\nLines 527: Wrap range(len(filenames)) in list() to materialize the lazy range   type.\ndatasets/download_imagenet.sh\nLines 72 and 81: Comment out wget commands, avoid downloading imagenet training   and validation data.\ndatasets/preprocess_imagenet_validation_data.py\nLine 1: #!/usr/bin/python -> #!/usr/bin/python3\nRemove importing of six.moves module.\nChange all instances of xrange to range. The range type in python3 behaves   just like the xrange type.\ndatasets/process_bounding_boxes.py\nLine 1: #!/usr/bin/python -> #!/usr/bin/python3\nRemove importing of six.moves module.\nChange all instance of xrange to range."
},

{
    "location": "datasets/slim/#Steps-for-building-slim-1",
    "page": "Tensorflow Slim",
    "title": "Steps for building slim",
    "category": "section",
    "text": "Put ILSVRC2012_img_train.tar and ILSVRC2012_img_val.tar in a known spot (<path/to/imagenet>) with 500GB+ of available memory.Navigate in this repository to: /datasets/imagenet/slim. Launch a Tensorflow docker container withdocker run -it --rm \\\n    -v <path/to/imagnet>:/imagenet \\\n    -v $PWD:/slim-builder \\\n    -e LOCAL_USER_ID=$UID \\\n    darchr/tf-compiled-base /bin/bashinside the docker container, run:cd slim-builder\n$PWD/download_and_convert_imagenet.sh /imagenetWhen prompted to enter in your credentials, just hit enter. The script won\'t download imagenet anyways so it doesn\'t matter what you put in.  Hopefully, everything works  as expected. If not, you can always edit the download_and_convert_imagenet.sh file,  commenting out the script/python invokations that have already completed."
},

{
    "location": "workloads/ubuntu/#",
    "page": "Ubuntu Workloads",
    "title": "Ubuntu Workloads",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/ubuntu/#Ubuntu-Workloads-1",
    "page": "Ubuntu Workloads",
    "title": "Ubuntu Workloads",
    "category": "section",
    "text": "Workloads that run under the official ubuntu docker image."
},

{
    "location": "workloads/ubuntu/#Launcher.TestWorkload",
    "page": "Ubuntu Workloads",
    "title": "Launcher.TestWorkload",
    "category": "type",
    "text": "Launch the test workload in a ubuntu image.\n\nFields\n\nnone\n\ncreate Keyword Arguments\n\nnone\n\n\n\n\n\n"
},

{
    "location": "workloads/ubuntu/#Test-1",
    "page": "Ubuntu Workloads",
    "title": "Test",
    "category": "section",
    "text": "A simple shell script that prints a message, sleeps for a few seconds, prints another message and exits. The point of this workload is to provide a simple and quick to run test to decrease debugging time.File name: /workloads/ubuntu/sleep.sh\nContainer entry point: /home/startup/sleep.shLauncher DocsLauncher.TestWorkload"
},

{
    "location": "workloads/tensorflow/#",
    "page": "Tensorflow Models",
    "title": "Tensorflow Models",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/tensorflow/#Tensorflow-Models-1",
    "page": "Tensorflow Models",
    "title": "Tensorflow Models",
    "category": "section",
    "text": ""
},

{
    "location": "workloads/tensorflow/#Launcher.ResnetTF",
    "page": "Tensorflow Models",
    "title": "Launcher.ResnetTF",
    "category": "type",
    "text": "Struct representing parameters for launching the Tensorflow Official Resnet Model on the  Imagenet training set. Construct type using a key-word constructor\n\nFields\n\nargs::NamedTuple - Arguments passed to the Keras Python script that creates and    trains Resnet.\ninteractive::Bool - Set to true to create a container that does not automatically run   Resnet when launched. Useful for debugging what\'s going on inside the container.\n\ncreate keywords\n\nmemory::Union{Nothing, Int} - The amount of memory to assign to this container. If   this value is nothing, the container will have access to all system memory.   Default: nothing.\ncpuSets = \"\" - The CPU sets on which to run the workload. Defaults to all processors.    Examples: \"0\", \"0-3\", \"1,3\".\n\n\n\n\n\n"
},

{
    "location": "workloads/tensorflow/#Resnet-1",
    "page": "Tensorflow Models",
    "title": "Resnet",
    "category": "section",
    "text": "A model for ResNet that can be trained on either Cifar or ImageNet, though as of now only ImageNet is supported.File: /workloads/tensorflow/official/resnet/imagenet_main.py\nContainer entry point: /models/official/resnet/imagenet_main.py\nDataset: \nVolume Binds:\nScript Arguments\n--batch_size=size : Configure batch size. Default: 32\n--resnet_size=size : Define the version of ResNet to use. Choices:    18, 34, 50, 101, 152, 200. Default: 50\n--train_epochs=N : Number of epochs to train for. Default: 90\n--data_dir=path : Path (inside the container) to the data directory. Default    provided by Launcher.  NOTE: If this is set to something besides /imagenet -    things will probably break horribly.Launcher DocsLauncher.ResnetTF"
},

{
    "location": "workloads/tensorflow/#Changes-Made-to-imagenet_main.py-1",
    "page": "Tensorflow Models",
    "title": "Changes Made to imagenet_main.py",
    "category": "section",
    "text": "Lines 42-47: Made script expect training and validation files to be in train and    validation directories respectively whereas the original expected both to be in   the same directory.\nAditionally, made the _NUM_TRAIN_FILES and _NUM_VALIDATION_FILES be assigned to   the number of files in these directories.\nThis allows us to operate on a subset of the ImageNet data by just pointing to another   folder.\nAlso hardcoded _DATA_DIR to /imagenet to allow this to take place. This limits the   migratability of this project outside of docker, but we\'ll deal with that when we need   to."
},

{
    "location": "workloads/slim/#",
    "page": "Slim",
    "title": "Slim",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/slim/#Slim-1",
    "page": "Slim",
    "title": "Slim",
    "category": "section",
    "text": "More information coming.For now, arguments that have to be passed to Launcher.Slim:args = (dataset_name=\"imagenet\", clone_on_cpu=true)"
},

{
    "location": "workloads/keras/#",
    "page": "Keras Models",
    "title": "Keras Models",
    "category": "page",
    "text": ""
},

{
    "location": "workloads/keras/#Keras-Models-1",
    "page": "Keras Models",
    "title": "Keras Models",
    "category": "section",
    "text": ""
},

{
    "location": "workloads/keras/#Launcher.CifarCnn",
    "page": "Keras Models",
    "title": "Launcher.CifarCnn",
    "category": "type",
    "text": "Workload object for the Keras Cifar10 cnn. Build type using keyword constructors.\n\nFields\n\nargs :: NamedTuple - Arguments to pass to the startup script (see docs).    Default: NamedTuple()\ninteractive :: Bool - If set to true, the container will launch into /bin/bash   instead of Python. Used for debugging the container. Default: false.\n\ncreate keywords\n\ncpuSets = \"\" - The CPU sets on which to run the workload. Defaults to all processors.    Examples: \"0\", \"0-3\", \"1,3\".\n\n\n\n\n\n"
},

{
    "location": "workloads/keras/#Cifar-Cnn-1",
    "page": "Keras Models",
    "title": "Cifar Cnn",
    "category": "section",
    "text": "A simple CNN for training on the cifar-10 dataset. This model is small enough that a couple epochs of training takes a reasonably short amount of time, even when snooping memory.File name: /workloads/keras/cifar_cnn.py\nContainer entry point: /home/startup/cifar_cnn.py\nDataset: cifar-10-batches-py.tar.gz    (https://www.cs.toronto.edu/~kriz/cifar-10-python.tar.gz)\nEndpoint for dataset in container: /home/user/.keras/datasets/cifar-10-batches-py.tar.gz.   If dataset doesn\'t exist, it will automatically be downloaded. However, this can take   a while and is a bit rude to the site hosting the dataset.\nScript Arguments:\n--batchsize [size] : Configure the batch size for training.\n--epochs [n] : Train for n epochs\n--abort : Import the keras and tensorflow libraries and then exit. Used for    testing the overhead of code loading.Launcher Docs:Launcher.CifarCnn"
},

{
    "location": "launcher/#",
    "page": "Launcher",
    "title": "Launcher",
    "category": "page",
    "text": ""
},

{
    "location": "launcher/#Launcher-1",
    "page": "Launcher",
    "title": "Launcher",
    "category": "section",
    "text": "Launcher is the Julia package (sorry, I really, really like writing Julia code) for handling the launching of containers, aggregation of results, binding containers with relevant datasets, and generally making sure everything is working correctly. Documentation for this package can be found in this section.The functionality provided by this model is very straightforward and can probably be ported to another language if needed.Note that Launcher is built on top of two other packages:DockerX - Package for interacting with   the Docker API.\nMemSnoop - Package for tracking the memory   usage patterns of applications on the Linux operating system.These two packages are still works in progress and documentation on them is forthcoming. However, I plan on registering at least DockerX and probably MemSnoop as well as soon as I take the time to get them production ready."
},

{
    "location": "launcher/#Base.run",
    "page": "Launcher",
    "title": "Base.run",
    "category": "function",
    "text": "run([f::Function], work::AbstractWorkload; showlog = false, kw...)\n\nCreate and launch a container from work with\n\ncontainer = create(work; kw...)\n\nStart the container and then call f(container). If f is not given, then attach to the container\'s stdout.\n\nThis function ensures that containers are stopped and cleaned up in case something goes wrong.\n\nIf showlog = true, send the container\'s log to stdout when the container stops.\n\n\n\n\n\n"
},

{
    "location": "launcher/#Launcher.AbstractWorkload",
    "page": "Launcher",
    "title": "Launcher.AbstractWorkload",
    "category": "type",
    "text": "Abstract supertype for workloads. Concrete subtypes should be implemented for each workload desired for analysis.\n\n\n\n\n\n"
},

{
    "location": "launcher/#Launcher.startfile",
    "page": "Launcher",
    "title": "Launcher.startfile",
    "category": "function",
    "text": "startfile(work::AbstractWorkload, ::Type{OnHost}) -> String\n\nReturn the path of the entrypoint file of work on the host machine.\n\nstartfile(work::AbstractWorkload, ::Type{OnContainer}) -> String\n\nReturn the path of the entrypoint file of work on the Docker Container.\n\n\n\n\n\n"
},

{
    "location": "launcher/#Launcher.runcommand",
    "page": "Launcher",
    "title": "Launcher.runcommand",
    "category": "function",
    "text": "runcommand(work::AbstractWorkload) -> Cmd\n\nReturn the Docker Container entry command for work.\n\n\n\n\n\n"
},

{
    "location": "launcher/#Launcher.create",
    "page": "Launcher",
    "title": "Launcher.create",
    "category": "function",
    "text": "create(work::AbstractWorkload; kw...) -> Container\n\nCreate a Docker Container for work, with optional keyword arguments. Concrete subtypes of AbstractWorkload must define this method and perform all the necessary steps to creating the Container. Note that the container should just be created by a call to DockerX.create_container, and not actually started.\n\nKeyword arguments supported by work should be included in that types documentation.\n\n\n\n\n\n"
},

{
    "location": "launcher/#Temporary-Documentation-1",
    "page": "Launcher",
    "title": "Temporary Documentation",
    "category": "section",
    "text": "Launcher.run\nLauncher.AbstractWorkload\nLauncher.startfile\nLauncher.runcommand\nLauncher.create"
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
