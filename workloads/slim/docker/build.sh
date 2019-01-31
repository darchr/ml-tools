#!/bin/bash

# First argument - path to the local tensorflow
docker build -t "darchr/tensorflow-mkl" . --build-arg tensorflow=$1
