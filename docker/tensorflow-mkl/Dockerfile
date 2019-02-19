# Docker image for running examples in Tensorflow models.
FROM ubuntu:18.04

RUN apt-get update && apt-get install -y make cmake libssl-dev openssl wget gcc g++ zlib1g-dev git libbz2-dev
RUN wget https://www.python.org/ftp/python/3.5.6/Python-3.5.6.tgz
RUN tar xzvf Python-3.5.6.tgz
WORKDIR Python-3.5.6
RUN ./configure
RUN make -j${nprocs}
RUN make install
RUN pip3 install --upgrade pip
RUN pip3 install --upgrade setuptools

#####
##### Base Tensorflow
#####

# Argument to the local tensorflow .whl. Make this a mandatory argument in case we change
# versions of tensorflow.
ARG tensorflow

# Add and install local tensorflow
ADD ${tensorflow} /home/${tensorflow}
RUN pip3 install /home/${tensorflow}

#####
##### Wrap up
#####

CMD ["/bin/bash"]
