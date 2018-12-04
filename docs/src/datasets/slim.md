# Tensorflow Slim

## Preparation steps (don't need to repeat)

The code in this repo is taken from the build process that comes in the `slim` project.
However, I've modified it so it works without having to go through Bazel (I don't really
know why that was used in the first place) and also updated it so it works with Python3.

### Changes made to build

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
    

## Steps for building `slim`

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
