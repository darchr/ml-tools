#!/bin/bash

# Need to navigate to the src directory in order to include the code.
cd ../../src/pytorch
docker build -t "darchr/gnmt" --rm -f ../../docker/gnmt/Dockerfile .
