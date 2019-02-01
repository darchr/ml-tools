FROM darchr/tensorflow-mkl

WORKDIR /research
ENV HOME /research

#RUN pip3 install --upgrade numpy scipy sklearn tf-nightly-gpu
# Mount data into the docker
ADD . /research/reinforcement
WORKDIR /research/reinforcement

RUN pip3 install --upgrade pip
RUN pip3 install --upgrade setuptools
RUN pip3 install -r minigo/requirements.txt

ENTRYPOINT ["/bin/bash"]
