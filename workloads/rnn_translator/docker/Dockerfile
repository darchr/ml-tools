# Use our own compiled version of pytorch with mkl for better CPU performance
#FROM darchr/pytorch-mkl
FROM pytorch/pytorch:0.4_cuda9_cudnn7

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Include the code directly in the container
ADD . /workspace/pytorch
RUN pip install -r /workspace/pytorch/requirements.txt

# Begin in the directory we just uploaded
WORKDIR /workspace/pytorch
