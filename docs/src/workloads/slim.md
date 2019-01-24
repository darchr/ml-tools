# VGG416/Slim

This is actually a collection of models implemented using using Tensorflow's Slim framework.
The original repo for these models is 
<https://github.com/tensorflow/models/tree/master/research/slim>.

When I benchmarked this against the official tensorflow models for Resnet, this 
implementation seemed to train a little faster. Plus, the official models did not have
VGG implemented, which is why I ended up using this implementation.

## Using from Launcher


## Dataset

This collection of models uses the Imagenet dataset.

### Preparation steps (don't need to repeat)

The code in this repo is taken from the build process that comes in the `slim` project.
However, I've modified it so it works without having to go through Bazel (I don't really
know why that was used in the first place) and also updated it so it works with Python3.

**Changes made to build**

* `download_and_convert_imagenet.sh`

    - Removed some build comments that are no longer relevant.

    - Line 59: Change path for `WORK_DIR` since we're no longer doing the Bazel style
        build.

    - Line 104: Change path to `build_iamgenet_data.py`.

    - Line 108: Put `python3` in front of script invocation. Get around executable
        permission errors.

* `datasets/build_imagenet_data.py`

    - Lines 213, 216, 217, and 224: Suffix `.encode()` on string arguments to pass them
        as bytes to `_bytes_feature`.

    - Lines 527: Wrap `range(len(filenames))` in `list()` to materialize the lazy range
        type.

* `datasets/download_imagenet.sh`
    - Lines 72 and 81: Comment out `wget` commands, avoid downloading imagenet training
        and validation data.

* `datasets/preprocess_imagenet_validation_data.py`
    - Line 1: `#!/usr/bin/python` -> `#!/usr/bin/python3`

    - Remove importing of `six.moves` module.

    - Change all instances of `xrange` to `range`. The `range` type in python3 behaves
        just like the xrange type.

* `datasets/process_bounding_boxes.py`
    - Line 1: `#!/usr/bin/python` -> `#!/usr/bin/python3`

    - Remove importing of `six.moves` module.

    - Change all instance of `xrange` to `range`.
    

### Steps for building `slim`

- Put `ILSVRC2012_img_train.tar` and `ILSVRC2012_img_val.tar` in a known spot 
(`<path/to/imagenet>`) with 500GB+ of available memory.

Navigate in this repository to: `/datasets/imagenet/slim`. Launch a Tensorflow docker
container with
```sh
docker run -it --rm \
    -v <path/to/imagnet>:/imagenet \
    -v $PWD:/slim-builder \
    -e LOCAL_USER_ID=$UID \
    darchr/tf-compiled-base /bin/bash
```
inside the docker container, run:
```sh
cd slim-builder
$PWD/download_and_convert_imagenet.sh /imagenet
```
When prompted to enter in your credentials, just hit enter. The script won't download
imagenet anyways so it doesn't matter what you put in.  Hopefully, everything works 
as expected. If not, you can always edit the `download_and_convert_imagenet.sh` file, 
commenting out the script/python invokations that have already completed.

## Docker - Tensorflow CPU

The Docker Hub where the most current version of this container lives is
here: <https://hub.docker.com/r/darchr/tf-compiled-base/>. This repo will be kept 
up-to-date as I make needed changes to the container.

I'm using the official tensorflow docker approach to compile and build the pip package for
tensor flow.

* <https://www.tensorflow.org/install/source>
* <https://www.tensorflow.org/install/docker>

Helpful post talking about docker permissions <https://denibertovic.com/posts/handling-permissions-with-docker-volumes/>

### Compilation Overview

Containers will be build incrementally, starting with `darchr/tf-compiled-base`, which
is the base image containing Tensorflow that has been compiled on `amarillo`. Compiling
Tensorflow is important because the default Tensorflow binary is not compiled to use AVX2
instructions. Using the very scientific "eyeballing" approach, this compiled version of
Tensorflow runs ~60% faster.

Other containers that use Tensorflow can be build from `darchr/tf-compiled/base`.

### `darchr/tf-compiled-base`

As a high level overview, we use an official Tensorflow docker containers to build a 
Python 3.5 "wheel" (package). We then use a Python 3.5.6 docker container as a base to 
install the compiled tensorflow wheel.

#### Compiling Tensorflow

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
bazel build --config=mkl --config=opt //tensorflow/tools/pip_package:build_pip_package
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt
chown $HOST_PERMS /mnt/tensorflow-1.12.0-cp35-cp35m-linux_x86_64.whl
```
#### Summary

```sh
docker pull tensorflow/tensorflow:1.12.0-devel-py3
docker run -it -w /tensorflow -v $PWD:/mnt -e HOST_PERMS="$(id -u):$(id -g)" tensorflow/tensorflow:nightly-devel-py3 bash
# inside container
git pull
./configure # Look at options above
bazel build --config=mkl --config=opt //tensorflow/tools/pip_package:build_pip_package
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt
chown $HOST_PERMS /mnt/tensorflow-1.12.0-cp35-cp35m-linux_x86_64.whl
```

#### Building the Docker Image

With the `.whl` for tensorflow build, we can build a new Docker container with this 
installed. For this step, move `tensorflow-...-.whl` into the `tf-compiled-base/` 
directory. Then, run the shell script:
```sh
./build.sh tensorflow-1.12.0-cp35-cm35m-linux_x86_64.whl
```
Finally, if necessary, push the image to the `darchr` docker hub via
```sh
docker push darchr/tf-compiled-base
```

#### Some Notes

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

## Script Arguments:

```
Generic training script that trains a model using a given dataset.
flags:

/models/slim/train_image_classifier.py:
  --adadelta_rho: The decay rate for adadelta.
    (default: '0.95')
    (a number)
  --adagrad_initial_accumulator_value: Starting value for the AdaGrad accumulators.
    (default: '0.1')
    (a number)
  --adam_beta1: The exponential decay rate for the 1st moment estimates.
    (default: '0.9')
    (a number)
  --adam_beta2: The exponential decay rate for the 2nd moment estimates.
    (default: '0.999')
    (a number)
  --batch_size: The number of samples in each batch.
    (default: '32')
    (an integer)
  --checkpoint_exclude_scopes: Comma-separated list of scopes of variables to exclude when restoring from a checkpoint.
  --checkpoint_path: The path to a checkpoint from which to fine-tune.
  --[no]clone_on_cpu: Use CPUs to deploy clones.
    (default: 'false')
  --dataset_dir: The directory where the dataset files are stored.
  --dataset_name: The name of the dataset to load.
    (default: 'imagenet')
  --dataset_split_name: The name of the train/test split.
    (default: 'train')
  --end_learning_rate: The minimal end learning rate used by a polynomial decay learning rate.
    (default: '0.0001')
    (a number)
  --ftrl_initial_accumulator_value: Starting value for the FTRL accumulators.
    (default: '0.1')
    (a number)
  --ftrl_l1: The FTRL l1 regularization strength.
    (default: '0.0')
    (a number)
  --ftrl_l2: The FTRL l2 regularization strength.
    (default: '0.0')
    (a number)
  --ftrl_learning_rate_power: The learning rate power.
    (default: '-0.5')
    (a number)
  --[no]ignore_missing_vars: When restoring a checkpoint would ignore missing variables.
    (default: 'false')
  --label_smoothing: The amount of label smoothing.
    (default: '0.0')
    (a number)
  --labels_offset: An offset for the labels in the dataset. This flag is primarily used to evaluate the VGG and ResNet architectures which do not use a background class for the ImageNet
    dataset.
    (default: '0')
    (an integer)
  --learning_rate: Initial learning rate.
    (default: '0.01')
    (a number)
  --learning_rate_decay_factor: Learning rate decay factor.
    (default: '0.94')
    (a number)
  --learning_rate_decay_type: Specifies how the learning rate is decayed. One of "fixed", "exponential", or "polynomial"
    (default: 'exponential')
  --log_every_n_steps: The frequency with which logs are print.
    (default: '10')
    (an integer)
  --master: The address of the TensorFlow master to use.
    (default: '')
  --max_number_of_steps: The maximum number of training steps.
    (an integer)
  --model_name: The name of the architecture to train.
    (default: 'inception_v3')
  --momentum: The momentum for the MomentumOptimizer and RMSPropOptimizer.
    (default: '0.9')
    (a number)
  --moving_average_decay: The decay to use for the moving average.If left as None, then moving averages are not used.
    (a number)
  --num_clones: Number of model clones to deploy. Note For historical reasons loss from all clones averaged out and learning rate decay happen per clone epochs
    (default: '1')
    (an integer)
  --num_epochs_per_decay: Number of epochs after which learning rate decays. Note: this flag counts epochs per clone but aggregates per sync replicas. So 1.0 means that each clone will go
    over full epoch individually, but replicas will go once across all replicas.
    (default: '2.0')
    (a number)
  --num_preprocessing_threads: The number of threads used to create the batches.
    (default: '4')
    (an integer)
  --num_ps_tasks: The number of parameter servers. If the value is 0, then the parameters are handled locally by the worker.
    (default: '0')
    (an integer)
  --num_readers: The number of parallel readers that read data from the dataset.
    (default: '4')
    (an integer)
  --opt_epsilon: Epsilon term for the optimizer.
    (default: '1.0')
    (a number)
  --optimizer: The name of the optimizer, one of "adadelta", "adagrad", "adam","ftrl", "momentum", "sgd" or "rmsprop".
    (default: 'rmsprop')
  --preprocessing_name: The name of the preprocessing to use. If left as `None`, then the model_name flag is used.
  --quantize_delay: Number of steps to start quantized training. Set to -1 would disable quantized training.
    (default: '-1')
    (an integer)
  --replicas_to_aggregate: The Number of gradients to collect before updating params.
    (default: '1')
    (an integer)
  --rmsprop_decay: Decay term for RMSProp.
    (default: '0.9')
    (a number)
  --rmsprop_momentum: Momentum.
    (default: '0.9')
    (a number)
  --save_interval_secs: The frequency with which the model is saved, in seconds.
    (default: '600')
    (an integer)
  --save_summaries_secs: The frequency with which summaries are saved, in seconds.
    (default: '600')
    (an integer)
  --[no]sync_replicas: Whether or not to synchronize the replicas during training.
    (default: 'false')
  --task: Task id of the replica running the training.
    (default: '0')
    (an integer)
  --train_dir: Directory where checkpoints and event logs are written to.
    (default: '/tmp/tfmodel/')
  --train_image_size: Train image size
    (an integer)
  --trainable_scopes: Comma-separated list of scopes to filter the set of variables to train.By default, None would train all the variables.
  --weight_decay: The weight decay on the model weights.
    (default: '4e-05')
    (a number)
  --worker_replicas: Number of worker replicas.
    (default: '1')
    (an integer)
```

## File Changes

**`train_image_classifier.py`**

* Line 62: Change default value of `log_every_n_steps` from 10 to 5.
