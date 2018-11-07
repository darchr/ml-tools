FROM darchr/tf-compiled-base

ADD requirements.txt /requirements.txt

# Set some environmental variables
ENV PYTHONPATH "${PYTHONPATH}:/models"
ENV PATH "$PATH:/root/.local/bin"

RUN pip3 install -r requirements.txt
