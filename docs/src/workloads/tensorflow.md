# Tensorflow Models

## Resnet

A model for ResNet that can be trained on either Cifar or ImageNet, though as of now only
ImageNet is supported.

* File: `/workloads/tensorflow/official/resnet/imagenet_main.py`
* Container entry point: `/models/official/resnet/imagenet_main.py`
* Dataset: 
* Volume Binds:

* **Script Arguments**
    * `--batch_size=size` : Configure batch size. Default: `32`
    * `--resnet_size=size` : Define the version of ResNet to use. Choices: 
        `18, 34, 50, 101, 152, 200`. Default: `50`
    * `--train_epochs=N` : Number of epochs to train for. Default: `90`
    * `--data_dir=path` : Path (inside the container) to the data directory. Default 
        provided by Launcher.  **NOTE**: If this is set to something besides `/imagenet` - 
        things will probably break horribly.

**Launcher Docs**
```@docs
Launcher.ResnetTF
```

## Changes Made to `imagenet_main.py`

* Lines 42-47: Made script expect training and validation files to be in `train` and 
    `validation` directories respectively whereas the original expected both to be in
    the same directory.

    Aditionally, made the `_NUM_TRAIN_FILES` and `_NUM_VALIDATION_FILES` be assigned to
    the number of files in these directories.

    This allows us to operate on a subset of the ImageNet data by just pointing to another
    folder.

    Also hardcoded `_DATA_DIR` to `/imagenet` to allow this to take place. This limits the
    migratability of this project outside of docker, but we'll deal with that when we need
    to.
