# Tensorflow CPU

We will use [Tensorflow](https://www.tensorflow.org/) as one of the ML frameworks for 
testing. Since the standard distribution for Tensorflow is not compiled with AVX2 
instructions, I compiled Tensorflow from source on `amarillo`. 

The Docker Hub where the most current version of this container lives is
here: <https://hub.docker.com/r/darchr/tf-compiled-base/>. This repo will be kept 
up-to-date as I make needed changes to the container.

I'm using the official tensorflow docker approach to compile and build the pip package for
tensor flow.

* <https://www.tensorflow.org/install/source>
* <https://www.tensorflow.org/install/docker>

Helpful post talking about docker permissions <https://denibertovic.com/posts/handling-permissions-with-docker-volumes/>

## Compilation Overview

Containers will be build incrementally, starting with `darchr/tf-compiled-base`, which
is the base image containing Tensorflow that has been compiled on `amarillo`. Compiling
Tensorflow is important because the default Tensorflow binary is not compiled to use AVX2
instructions. Using the very scientific "eyeballing" approach, this compiled version of
Tensorflow runs ~60% faster.

Other containers that use Tensorflow can be build from `darchr/tf-compiled/base`.

## `darchr/tf-compiled-base`

As a high level overview, we use an official Tensorflow docker containers to build a 
Python 3.5 "wheel" (package). We then use a Python 3.5.6 docker container as a base to 
install the compiled tensorflow wheel.

### Compiling Tensorflow

Pull the docker container with the source code:
```sh
docker pull tensorflow/tensorflow:1.12.0-devel-py3
```

Launch the container with
```sh
docker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS="$(id -u):$(id -g)" tensorflow/tensorflow:1.12.0-devel-py3 bash
```

This does the following:

* Opens the container in the `/tensorflow` directory, which contains the tensorflow source
    code

* Mounts the current directory into the `/mnt` directory in the container. This allows the
    .whl build to be dropped in the PWD after compilation.

Inside the container, run
```sh
git pull
```
to pull the latest copy of the tensorflow source. Then configure the build with
```sh
./configure
```
Settings used:
* Python Location: default
* Python Library Path: default
* Apache Ignite Support: Y
* XLA Jit support: Y
* OpenCL SYCL support: N
* ROCm support: N
* CUDA support: N
* Fresh clang release: N
* MPI support: N
* Optimization flags: default
* Interactively configure ./WORKSPACE: N


Steps to build:
```
bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt
chown $HOST_PERMS /mnt/tensorflow-1.12.1-cp35-cp35m-linux_x86_64.whl
```
Note, compilation takes quite a while, so be patient. If running on amarillo, enjoy the
96 thread awesomeness.

#### Summary

```sh
docker pull tensorflow/tensorflow:nightly-devel-py3
docker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS="$(id -u):$(id -g)" tensorflow/tensorflow:nightly-devel-py3 bash
# inside container
git pull
./configure # Look at options above
bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt
chown $HOST_PERMS /mnt/tensorflow-1.12.1-cp35-cp35m-linux_x86_64.whl
```

### Building the Docker Image

With the `.whl` for tensorflow build, we can build a new Docker container with this 
installed. For this step, move `tensorflow-...-.whl` into the `tf-compiled-base/` 
directory. Then, run the shell script:
```sh
./build.sh tensorflow-1.12.1-cp35-cm35m-linux_x86_64.whl
```
Finally, if necessary, push the image to the `darchr` docker hub via
```sh
docker push darchr/tf-compiled-base
```

### Some Notes

Annoyingly, the `.whl` created in the previous step only works with Python 3.5. I tried 
hacking it by changing the name (cp35-cp35m -> cp36-cp36m), but installation with `pip` 
failed. This means that we need a working copy of Python 3.5 in order to run this. 
Fortunately, the Python foundation supplies Debian (I think ... or Ubuntu) based containers
for past Python versions. We can use this as a starting point for our `Dockerfile`.

Permissions with the docker containers was becoming a bit of a nightmare. I finally
found a solution that works by installing `gosu`:

* <https://github.com/tianon/gosu>
* <https://denibertovic.com/posts/handling-permissions-with-docker-volumes/>

Essentially, a dummy account `user` is created that does not have root privileges, but we
can still create directories within the docker containers.

## Tensorflow 0.12.1

The French Street signs model requires an older version of tensorflow.

```sh
docker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS="$(id -u):$(id -g)" tensorflow/tensorflow:0.12.1-devel bash
```
Then run
```sh
git pull
python2 -m pip install --upgrade requests
python2 -c "import requests; print(requests.get('https://www.howsmyssl.com/a/check', verify=False).json()['tls_version'])"
apt-get update && apt-get install vim
vim tensorflow/workspace.bzl
```
The `python2` commands come from <https://pyfound.blogspot.com/2017/01/time-to-upgrade-your-python-tls-v12.html>

Inside the workspace, comment out the sha256 lines for everything from GitHub. Apprently
GitHub changed something about their stored tarballs that 


./configure


```
The commands I used were

* Python path: Default (`/usr/bin/python`)
* Google cloud platform support: N
* Hadoop file system: N
* Python library: Default (`/usr/local/lib/python2.7/dist-packages`)
* OpenCL: N
* GPU Support: N

