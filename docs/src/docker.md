# Docker Container Hierarchy

The docker container hierarchy is a little confusing because of layering. At some point, 
this needs a refactoring, but I don't want to sink a whole bunch of effort into it yet.

For now, here's a list of the docker containers, they're relevant projects, and their
dependencies. Base docker containers (not requiring any other docker images to build on top
of) are listed first.

## darchr/tensorflow-mkl

**Description:** Tensorflow compiled with MKL

**Prerequisite Builds:** None

**Workloads**: Slim, Inception v4, Minigo, 3dUnet


## darchr/gnmt

**Description:** Pytorch container with the dependencies for the RNN translator `seq2seq`.
Note that this container comes with mkl preinstalled. I tried making a container with
my own compiled version of PyTorch, but always recieved worse results than the default.

**Prerequisite Builds:** None

**Workloads**: RNN Translator


## darchr/reinforcement

**Description:** Tensorflow container with some more items for the Minigo/reinforcement
learning application.

**Prerequisite Builds:** `darchr/tensorflow-mkl`

**Workloads**: Minigo/Reinforcement


## darchr/ants

**Description:** Docker image with tensorflow and a compiled version of the image processing
tool <https://github.com/ANTsX/ANTs>.

**Prerequisite Builds:** `darchr/tensorflow-mkl`

**Workloads**: None, just used as an intermediate container because compiling ANTs is a pain
in the ass and takes a while.


## darchr/3dunet

**Description:** Docker image containiner the dependencies for the 3dUnet implementation
<https://github.com/ellisdg/3DUnetCNN>.

**Prerequisite Builds:** `darchr/ants`, `darchr/tensorflow-mkl`

**Workloads**: 3dUnet
