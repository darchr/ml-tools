# Keras Models

## Cifar Cnn

A simple CNN for training on the cifar-10 dataset. This model is small enough that a couple
epochs of training takes a reasonably short amount of time, even when snooping memory.

* File name: `/workloads/keras/cifar_cnn.py`
* Container entry point: `/home/startup/cifar_cnn.py`
* Dataset: `cifar-10-batches-py.tar.gz` 
    (<https://www.cs.toronto.edu/~kriz/cifar-10-python.tar.gz>)
* Endpoint for dataset in container: `/home/user/.keras/datasets/cifar-10-batches-py.tar.gz`.
    If dataset doesn't exist, it will automatically be downloaded. However, this can take
    a while and is a bit rude to the site hosting the dataset.
* **Script Arguments**:
    * `--batchsize [size]` : Configure the batch size for training.
    * `--epochs [n]` : Train for `n` epochs
    * `--abort` : Import the keras and tensorflow libraries and then exit. Used for 
        testing the overhead of code loading.

**Launcher Docs**:
```@docs
Launcher.CifarCnn
```

## Resnet Cnn
TODO
