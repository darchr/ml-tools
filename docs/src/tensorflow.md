# Tensorflow

We will use [Tensorflow](https://www.tensorflow.org/) as one of the ML frameworks for 
testing. Since the standard distribution for Tensorflow is not compiled with AVX2 
instructions, I compiled Tensorflow from source on `amarillo`. The directory `tf-compile/`
has the relevant files for how this is done.

The Docker Hub where the most current version of this container lives is
here: <https://hub.docker.com/r/darchr/tf-compiled-base/>. This repo will be kept 
up-to-date as I make needed changes to the container.

The next few sections will detail the steps taken to compile Tensorflow as well as the
other containers used.
