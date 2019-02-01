# BraTS

Brain Tumor Segmentation library. Specifically, the 2018 edition. Getting this dataset is
kind of a pain because you have to register, and then the people hosting the registration
don't actually tell you when your registration is ready.

More information can be found at <https://www.med.upenn.edu/sbia/brats2018/data.html>

Once you have the `zip` file of the data, titled `MICCAI_BraTS_2018_Data_Training.zip`, 
getting it into a format that is useable by the 3dUnetCNN workload is pretty involved:

## Preprocessing

Create a directory where the dataset will go, and make a folder called "original" in it.
```
mkdir ~/brats
cd brats
mkdir original
cd original
```
Move the zip file into the `original` folder
```
mv <zip-path> .
```
Unzip the contents of the file
```
unzip `MICCAI_BraTS_2018_Data_Training.zip`
```
Now, go build the docker container `darchr/3dunet` (see the 3dunet page). Once that is done,
run the `preprocess.sh` script in `workloads/3dUnet/dataset/preprocess.sh` using
```
./preprocess.sh ~/brats
```
Go have a snack while this thing runs. I'm sorry if you don't have a machine with 96 
processors because it will take a while.

Once the preprocess script is done, there's still more preprocessing to do. Unfortunately,
factoring out the code that runs this step proved to be more challenging than I was willing
to deal with, so you will have to run this workload. Basically, the first step that the 
3dUnet implementation does is to turn all the preprocessed files into a gigantic hdf5 file.
But, it only has to do it once.

Make sure you register the location of the `brats` data repo in Launcher with
```
cd Launcher

julia
```
```julia
julia> using Launcher

julia> Launcher.edit_setup()
```
Then, run the workload with
```julia
julia> workload = Launcher.Unet()

julia> run(workload)
```
Wait patiently the initial conversion to hdf5 to complete. Once it does, you'll never have
to deal with this stuff again (hopefully).

## Problems + Solutions

* The python:3.5.6 docker container had a operating system that was to old for the compilers/
    cmake versions to build ANTs. Thus, I switched `darchr/tensorflow-mkl` to be based on
    ubuntu 18.04 and build python 3.5.6 from source in that container.

* When building ANTs, the make process would just hang when trying to download TKv5 (or 
    something with a name very similar to that). The problem was with the git protocol used
    to clone the repository. The solution to this was to pass a flag to cmake:
```
cmake -DSuperBuild_ANTS_USE_GIT_PROTOCOL=OFF ../ANTs
```

* The 3dUnet implementation, especially the data loading from the HDF5 file is insanely 
    buggy - it would immediately segfault then loading data. My solutions to this, taken 
    from comments of users in issues for the repository, was to

    - Turn off compresion into the HDF5 file in `data.py`, line 12: change the key word 
        arguments to just `complevel=0`

    - Enable multithreading in the training loop `training.py`: add the argument
        `use_multiprocessing = True` to the fall to `fit_generator` on line 78.
