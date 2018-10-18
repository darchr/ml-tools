# Start from the base compiled image
FROM darchr/tf-compiled-base

RUN pip3 install keras

# Make the keras directory and make readable/writable by all
RUN mkdir .keras
RUN mkdir .keras/datasets
RUN chmod 777 -R /.keras
