## Imagenet for Metalhead (Julia - experimental)

Navigate to the directory where the dataset will live. We are going to use an 
[unofficial Kaggle CLI](https://github.com/floydwch/kaggle-cli) that supports resuming 
downloads to download the dataset.

Sign up for Kaggle and register for the imagenet challenge at <https://www.kaggle.com/c/imagenet-object-localization-challenge/data>

Launch a docker container with

```sh
docker run -v $PWD:/data -it --rm python:3.6 /bin/bash
```
Inside the container:
```sh
pip3 install kaggle-cli
cd data
kg download -c imagenet-object-localization-challenge -u <username> -p <password>
```

