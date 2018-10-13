# Building Tensorflow from source

I'm using the official tensorflow docker approach to compile and build the pip package for
tensor flow.
```
https://www.tensorflow.org/install/source
https://www.tensorflow.org/install/docker
```

## Compilation Overview

Containers will be build incrementally, starting with `darchr/tf-compiled-base`, which
is the base image containing Tensorflow that has been compiled on `amarillo`. Compiling
Tensorflow is important because the default Tensorflow binary is not compiled to use AVX2
instructions. Using the very scientific "eyeballing" approach, this compiled version of
Tensorflow runs ~60% faster.


## Building `tf-compiled-base`

As a high level overview, we use an official Tensorflow docker containers to build a 
Python 3.5 "wheel" (package). We then use a Python 3.5.6 docker container as a base to 
install the compiled tensorflow wheel.

### Compiling Tensorflow

Pull the docker container with the source code:
```sh
docker pull tensorflow/tensorflow:nightly-devel-py3
```

Launch the container with
```sh
docker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS="$(id -u):$(id -g)" tensorflow/tensorflow:nightly-devel-py3 bash
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
./configure # I just used all defaults for now
```

Steps to build:
```
bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt
chown $HOST_PERMS /mnt/tensorflow-1.11.0rc1-cp35-cp35m-linux_x86_64.whl
```
Note, compilation takes quite a while, so be patient. If running on amarillo, enjoy the
96 thread awesomeness.

#### Summary

```sh
docker pull tensorflow/tensorflow:nightly-devel-py3
docker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS="$(id -u):$(id -g)" tensorflow/tensorflow:nightly-devel-py3 bash
# inside container
git pull
./configure # I just used all defaults for now
bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt
chown $HOST_PERMS /mnt/tensorflow-1.11.0rc1-cp35-cp35m-linux_x86_64.whl
```

### Building `tf-compiled-base`

With the `.whl` for tensorflow build, we can build a new Docker container with this 
installed. For this step, move `tensorflow-...-.whl` into the `tf-compiled-base/` 
directory.

Annoyingly, the `.whl` created in the previous step only works with Python 3.5. I tried 
hacking it by changing the name (cp35-cp35m -> cp36-cp36m), but installation with `pip` 
failed. This means that we need a working copy of Python 3.5 in order to run this. 
Fortunately, the Python foundation supplies Debian (I think ... or Ubuntu) based containers
for past Python versions. We can use this as a starting point for our `Dockerfile`.

The Dockerfile is pretty self-explanatory. The one tricky bit is that the 
tensorflow `.whl` built in the previous step must be linked to the container so we can 
install the compiled tensorflow. You can use the build script as
```sh
./build.sh tensorflow-1.11.0rc1-cp35-cm35m-linux_x86_64.whl
```
or run the docker command directly as
```sh
docker build -t darchr/tf-compiled-base . --build-arg tensorflow=tensorflow-1.11.0rc1-cp35-cp35m-linux_x86_64.whl
```

As a side note, I've added [sysstat](https://github.com/sysstat/sysstat) to the Docker image
to allow collection of CPU and memory data.

To push the container to the Docker hub repository, run
```sh
docker push darchr/tf-compiled-base
```

### Using `tf-compiled-base`
Finally, we can run the compiled container with
```
docker run -it --rm darchr/tf-compiled-base /bin/bash
```
New containers can be layered on top of this base by beginning new Dockerfiles with
```
FROM darchr/tf-compiled-base
```

# Custom containers built on top of `tf-compiled-base`
## `tf-resnet`

Image for running Resnet based on the [keras](https://github.com/keras-team/keras) framework.
Just enter the `tf-resnet/` directory and run
```
./build.sh
```
To build the container. Running the container can be controlled from `Launcher.jl` (needs
documentation)

### Issues
* In order to work without throwing an error (thanks keras-team), we must set
    ```python
    data_augmentation = False
    ```
    Thus, I just copied the `cifar10_resnet.py` file, changed the required line, and linked
    it into the container during the build process.
