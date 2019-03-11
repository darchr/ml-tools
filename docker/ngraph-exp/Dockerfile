FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
    make \
    curl \
    cmake \
    python \
    clang \
    libssl-dev \
    openssl \
    wget \
    git \
    unzip \
    build-essential \
    clang-format \
    zlib1g \
    zlib1g-dev \
    libtinfo-dev \
    autoconf \
    automake \
    libtool

#####
##### Install Julia
#####

# Download the julia tar
ARG JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1.0-linux-x86_64.tar.gz"
RUN wget $JULIA_URL

# Uncompress
ARG OUTPUT_DIR="/"
RUN tar -xzf $(basename ${JULIA_URL}) -C ${OUTPUT_DIR}

# Remove tarball
RUN rm $(basename ${JULIA_URL})
ENV PATH $PATH:"/julia-1.1.0/bin"

#####
##### Add the nGraph stuff
#####
WORKDIR /home
RUN git clone --depth=1 https://github.com/hildebrandmw/nGraph.jl nGraph

# Get around a wierd Pkg error by running the command twice. YOLO
RUN julia -e 'using Pkg; try Pkg.develop(PackageSpec(path = "./nGraph")); catch e; Pkg.develop(PackageSpec(path = "./nGraph")); end'

# Build nGraph
RUN julia -e 'using Pkg; Pkg.build(verbose = true)'
RUN julia -e 'using Pkg; Pkg.add("ArgParse"); Pkg.add("Metalhead")'

# Get a "ResNet" model in Metalhead to download the weights
RUN julia -e 'using Metalhead; Metalhead.ResNet()'
