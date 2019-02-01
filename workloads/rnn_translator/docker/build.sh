#!/bin/bash
cd ../src/pytorch
docker build -t "darchr/gnmt" --rm -f ../../docker/Dockerfile .
