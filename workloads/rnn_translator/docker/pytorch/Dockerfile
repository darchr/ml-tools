# Installation instructions from the PyTorch README:
#
# https://github.com/pytorch/pytorch#from-source
FROM continuumio/anaconda3:5.3.0

RUN apt-get update && apt-get install -y wget
RUN wget https://repo.anaconda.com/archive/Anaconda3-2018.12-Linux-x86_64.sh

# Need to install a compiler
RUN apt-get update && apt-get install -y gcc g++ make libomp-dev

# Install dependencies for PyTorch, includeing MKL
RUN conda install -y numpy pyyaml mkl mkl-include setuptools cmake cffi typing
RUN conda install -y -c mingfeima mkldnn

# Expect to be in the home directory
RUN git clone --branch v1.0.0 --depth 1 --recursive https://github.com/pytorch/pytorch

RUN export CMAKE_PREFIX_PATH=${CONDA_PREFIX:-"$(dirname $(which conda))/../"}
RUN cd /pytorch && python setup.py install
