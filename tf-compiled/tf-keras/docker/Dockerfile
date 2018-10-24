# Start from the base compiled image
FROM darchr/tf-compiled-base

RUN pip3 install keras

# # Make the keras directory and make readable/writable by all
# RUN mkdir /home/user/.keras
# RUN mkdir /home/user/.keras/datasets
# RUN chown -Ruser  /home/user

# Make this directory and set it to readable and writable by all.
# -- This is where keras stores its saved models. Adding this directory allows keras to make
# its validation run. Otherwise, it just errors out.
# RUN mkdir /saved_models
# RUN chmod 777 -R /saved_models
