# Docker image for running examples in Tensorflow models.
# base_image depends on whether we are running on GPUs or non-GPUs
FROM python:3.5.6

# Argument to the local tensorflow .whl. Make this a mandatory argument in case we change
# versions of tensorflow.
ARG tensorflow

# Add and install local tensorflow
ADD ${tensorflow} /home/${tensorflow}
RUN pip3 install /home/${tensorflow}

# Add entrypoint shenanigans to deal with permissions
RUN apt-get update && apt-get -y --no-install-recommends install \
    ca-certificates \
    curl

RUN gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.11/gosu-$(dpkg --print-architecture)" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.11/gosu-$(dpkg --print-architecture).asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 777 /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
