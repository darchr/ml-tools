FROM ubuntu:18.04

# The stupid package "tzdata" wants to know our timezone.
# make it shutup by setting "DEBIAN_FRONTEND" to "noninteractive"
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libopenblas-dev \
    libopencv-dev \
    ca-certificates \
    make


# Clone mxnet and build
RUN git clone --recursive https://github.com/apache/incubator-mxnet.git mxnet
RUN cd mxnet && make -j $(nproc) USE_OPENCV=1 USE_BLAS=openblas

RUN export LD_LIBRARY_PATH=/incubator-mxnet/lib
