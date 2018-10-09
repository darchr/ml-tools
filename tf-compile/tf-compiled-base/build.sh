#!/bin/bash

# First argument - path to the local tensorflow
docker build -t "hildebrandmw/tf-compiled-base" . --build-arg tensorflow=$1
