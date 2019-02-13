#!/bin/bash

# Need to navigate to the src directory in order to include the code.
DIR=${PWD}
cd ../../workloads/rnn_translator/src/pytorch
docker build -t "darchr/gnmt" --rm -f $DIR/Dockerfile .
