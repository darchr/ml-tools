# Docker image for running examples in Tensorflow models.
# base_image depends on whether we are running on GPUs or non-GPUs
FROM python:3.5
#FROM tensorflow/tensorflow:1.12.0-devel-py3

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
##### Keras Dependencies
#####

RUN pip3 install keras

# Make this directory and set it to readable and writable by all.
# -- This is where keras stores its saved models. Adding this directory allows keras to make
# its validation run. Otherwise, it just errors out.
RUN mkdir /saved_models
RUN chmod 777 -R /saved_models

#####
##### Official Models dependencies
#####

ADD requirements.txt /requirements.txt

# Set some environmental variables
ENV PYTHONPATH "${PYTHONPATH}:/models"
ENV PATH "$PATH:/root/.local/bin"

RUN pip3 install -r /requirements.txt

#####
##### Wrap up
#####

CMD ["/bin/bash"]
