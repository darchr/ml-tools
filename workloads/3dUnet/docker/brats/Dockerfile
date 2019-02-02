FROM darchr/ants

RUN apt-get install libbz2-dev

ENV PYTHONPATH=/brats_repo:$PYHONPATH
ENV PATH=/ANTs/build/bin:$PATH

#RUN apt-get update &&  apt-get upgrade -y &&  apt-get dist-upgrade -y &&  apt-get autoremove -y && apt-get autoclean -y
RUN apt-get install -y libhdf5-dev

# Install python dependencies
RUN pip3 install h5py numexpr cython nibabel keras nilearn SimpleITK nipype sklearn tables
RUN pip3 install git+https://www.github.com/keras-team/keras-contrib.git
