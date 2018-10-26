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
    "text": "Documentation on the ML-Tools repo*"
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
    "text": "The notebooks in this repo contain plots and run scripts to generate the data for those  plots. The contents of the notebooks are summarised here and contain links to the rendered notebooks are included.In general, each directory contains a notebook and a collection of scripts. Since sudo access is needed to run MemSnoop, these scripts are stand-alone. Note that these scripts should be run before the notebooks if trying to recreate the plots."
},

{
    "location": "notebooks.html#[Basic-Analysis](https://github.com/darchr/ml-tools/blob/master/notebooks/basic_analysis/basic_analysis.ipynb)-1",
    "page": "Notebooks",
    "title": "Basic Analysis",
    "category": "section",
    "text": "Basic analysis of the memory usage during the training of a simple CNN on a single CPU. The sampling window was 0.2 seconds. That is, the sampling procedure went something like this:Mark all the applications pages as idle.\nRun applition for 0.2 seconds\nPause application\nDetermine which pages are active and update datastructures.\nRepeat"
},

{
    "location": "notebooks.html#[CPU-Analysis](https://github.com/darchr/ml-tools/blob/master/notebooks/cpu_analysis/cpu_analysis.ipynb)-1",
    "page": "Notebooks",
    "title": "CPU Analysis",
    "category": "section",
    "text": "Plots and some analysis of how the memory requirements and training speed for 2 epochs of  training scale as the number of available processors is increased."
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
    "text": "We will use Tensorflow as one of the ML frameworks for  testing. Since the standard distribution for Tensorflow is not compiled with AVX2  instructions, I compiled Tensorflow from source on amarillo. The directory tf-compile/ has the relevant files for how this is done.The Docker Hub where the most current version of this container lives is here: https://hub.docker.com/r/darchr/tf-compiled-base/. This repo will be kept  up-to-date as I make needed changes to the container.The next few sections will detail the steps taken to compile Tensorflow as well as the other containers used."
},

{
    "location": "tf-compiled-base.html#",
    "page": "Building Tensorflow",
    "title": "Building Tensorflow",
    "category": "page",
    "text": ""
},

{
    "location": "tf-compiled-base.html#Building-Tensorflow-1",
    "page": "Building Tensorflow",
    "title": "Building Tensorflow",
    "category": "section",
    "text": "I\'m using the official tensorflow docker approach to compile and build the pip package for tensor flow.https://www.tensorflow.org/install/source\nhttps://www.tensorflow.org/install/dockerHelpful post talking about docker permissions https://denibertovic.com/posts/handling-permissions-with-docker-volumes/"
},

{
    "location": "tf-compiled-base.html#Compilation-Overview-1",
    "page": "Building Tensorflow",
    "title": "Compilation Overview",
    "category": "section",
    "text": "Containers will be build incrementally, starting with darchr/tf-compiled-base, which is the base image containing Tensorflow that has been compiled on amarillo. Compiling Tensorflow is important because the default Tensorflow binary is not compiled to use AVX2 instructions. Using the very scientific \"eyeballing\" approach, this compiled version of Tensorflow runs ~60% faster."
},

{
    "location": "tf-compiled-base.html#Building-tf-compiled-base-1",
    "page": "Building Tensorflow",
    "title": "Building tf-compiled-base",
    "category": "section",
    "text": "As a high level overview, we use an official Tensorflow docker containers to build a  Python 3.5 \"wheel\" (package). We then use a Python 3.5.6 docker container as a base to  install the compiled tensorflow wheel."
},

{
    "location": "tf-compiled-base.html#Compiling-Tensorflow-1",
    "page": "Building Tensorflow",
    "title": "Compiling Tensorflow",
    "category": "section",
    "text": "Pull the docker container with the source code:docker pull tensorflow/tensorflow:nightly-devel-py3Launch the container withdocker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS=\"$(id -u):$(id -g)\" tensorflow/tensorflow:nightly-devel-py3 bashThis does the following:Opens the container in the /tensorflow directory, which contains the tensorflow source   code\nMounts the current directory into the /mnt directory in the container. This allows the   .whl build to be dropped in the PWD after compilation.Inside the container, rungit pullto pull the latest copy of the tensorflow source. Then configure the build with./configure # I just used all defaults for nowSteps to build:bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package\n./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt\nchown $HOST_PERMS /mnt/tensorflow-1.11.0rc1-cp35-cp35m-linux_x86_64.whlNote, compilation takes quite a while, so be patient. If running on amarillo, enjoy the 96 thread awesomeness."
},

{
    "location": "tf-compiled-base.html#Summary-1",
    "page": "Building Tensorflow",
    "title": "Summary",
    "category": "section",
    "text": "docker pull tensorflow/tensorflow:nightly-devel-py3\ndocker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS=\"$(id -u):$(id -g)\" tensorflow/tensorflow:nightly-devel-py3 bash\n# inside container\ngit pull\n./configure # I just used all defaults for now\nbazel build --config=opt //tensorflow/tools/pip_package:build_pip_package\n./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt\nchown $HOST_PERMS /mnt/tensorflow-1.11.0rc1-cp35-cp35m-linux_x86_64.whl"
},

{
    "location": "tf-compiled-base.html#Building-tf-compiled-base-2",
    "page": "Building Tensorflow",
    "title": "Building tf-compiled-base",
    "category": "section",
    "text": "With the .whl for tensorflow build, we can build a new Docker container with this  installed. For this step, move tensorflow-...-.whl into the tf-compiled-base/  directory.Annoyingly, the .whl created in the previous step only works with Python 3.5. I tried  hacking it by changing the name (cp35-cp35m -> cp36-cp36m), but installation with pip  failed. This means that we need a working copy of Python 3.5 in order to run this.  Fortunately, the Python foundation supplies Debian (I think ... or Ubuntu) based containers for past Python versions. We can use this as a starting point for our Dockerfile.The Dockerfile is pretty self-explanatory. The one tricky bit is that the  tensorflow .whl built in the previous step must be linked to the container so we can  install the compiled tensorflow. You can use the build script as./build.sh tensorflow-1.11.0rc1-cp35-cm35m-linux_x86_64.whlor run the docker command directly asdocker build -t darchr/tf-compiled-base . --build-arg tensorflow=tensorflow-1.11.0rc1-cp35-cp35m-linux_x86_64.whl"
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

]}
