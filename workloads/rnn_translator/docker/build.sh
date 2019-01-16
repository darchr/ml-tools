
DIR=$PWD
cd ../src/pytorch

docker build -t "gnmt:latest" --rm -f ../../docker/Dockerfile .
