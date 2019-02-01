#!/bin/bash
<<<<<<< HEAD
=======

# Need to navigate to the src directory in order to include the code.
>>>>>>> c4f4f8adba18c015b92cb5c5af500e85684560ac
cd ../src/pytorch
docker build -t "darchr/gnmt" --rm -f ../../docker/Dockerfile .
