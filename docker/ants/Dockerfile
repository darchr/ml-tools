FROM darchr/tensorflow-mkl

# Install the image processing dependency
RUN mkdir ANTs
WORKDIR /ANTs
RUN git clone https://github.com/stnava/ANTs.git
RUN mkdir bin
WORKDIR /ANTs/build
RUN cmake -DSuperBuild_ANTS_USE_GIT_PROTOCOL=OFF ../ANTs
RUN make -j${nprocs}

ENV PATH="$PATH:/ANTs/build/bin"
