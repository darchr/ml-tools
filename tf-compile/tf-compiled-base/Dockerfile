# Docker image for running examples in Tensorflow models.
# base_image depends on whether we are running on GPUs or non-GPUs
FROM python:3.5.6

# Argument to the local tensorflow .whl. Make this a mandatory argument in case we change
# versions of tensorflow.
ARG tensorflow

RUN apt-get update && apt-get install -y --no-install-recommends collectl

# Map over the local "sysstat" file to enable data collection.
# ADD sysstat /etc/default/sysstat
# RUN service sysstat restart

# Add and install local tensorflow
ADD ${tensorflow} /home/${tensorflow}
RUN pip3 install /home/${tensorflow}
