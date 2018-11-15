# Tensorflow Models

## Resnet

A model for ResNet that can be trained on either Cifar or ImageNet, though as of now only
ImageNet is supported.

* File: `/workloads/tensorflow/official/resnet/imagenet_main.py`
* Container entry point: `/models/official/resnet/imagenet_main.py`
* Dataset: 
* Volume Binds:

* **Script Arguments**
    * `--batchsize=size` : Configure batch size. Default: `32`
    * `--resnet_size=size` : Define the version of ResNet to use. Choices: 
        `18, 34, 50, 101, 152, 200`. Default: `50`
    * `--train_epochs=N` : Number of epochs to train for. Default: `90`
    * `--data_dir=path` : Path to the data directory. Default provided by Launcher.

**Launcher Docs**
```@docs
Launcher.ResnetTF
```
