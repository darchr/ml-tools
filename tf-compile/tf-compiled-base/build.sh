#!/bin/bash

# First argument - path to the local tensorflow
docker build -t "darchr/tf-compiled-base" . --build-arg tensorflow=$1
