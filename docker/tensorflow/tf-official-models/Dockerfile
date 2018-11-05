FROM darchr/tf-compiled-base

ADD requirements.txt /requirements.txt

RUN export PYTHONPATH="$PYTHONPATH:/models"
RUN export PATH="$PATH:/root/.local/bin"
RUN pip3 install -r requirements.txt
