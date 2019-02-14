# Imagenet

Navigate to the directory where the dataset will live. We are going to use an 
[unofficial Kaggle CLI](https://github.com/floydwch/kaggle-cli) that supports resuming 
downloads to download the dataset.

Sign up for Kaggle and register for the imagenet challenge at <https://www.kaggle.com/c/imagenet-object-localization-challenge/data>

Launch a docker container with

```sh
docker run -v $PWD:/data -it --rm python:3.6 /bin/bash
```
Inside the container:
```sh
pip3 install kaggle-cli
cd data
kg download -c imagenet-object-localization-challenge -u <username> -p <password>
```

## Slim Preprocessing

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
