docker run -it -w /mnt \
    -v $PWD:/mnt \
    -e HOST_PERMS="$(id -u):$(id -g)" tensorflow/tensorflow:1.12.0-devel-py3 ./script.sh
