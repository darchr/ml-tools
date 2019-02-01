dir=$PWD

cd $dir/ants
docker build -t "darchr/ants" --rm -f ./Dockerfile .

cd $dir/brats
docker build -t "darchr/3dunet" --rm -f ./Dockerfile .
