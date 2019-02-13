#!/bin/bash

# Move to the /tensorflow repo
cd /tensorflow

# Build the package
bazel build --config=mkl --copt=-march=native --copt=-mtune=native //tensorflow/tools/pip_package:build_pip_package

# Create .whl and dump it in the /mnt directory
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt

# Change permissions on the file to avoid it being owned by root
chown $HOST_PERMS /mnt/tensorflow-1.12.0-cp35-cp35m-linux_x86_64.whl
