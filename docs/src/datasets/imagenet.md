# Imagenet

## Getting the Datasets

Theoretically, you can download the original 2012 Imagenet images from 
<http://image-net.org/download-images> by first registering. However, when I tried that,
I never received an email confirming my registration and thus allowing me to download. I had
to resort to ... other means.

In the process of searching for where to download, I came across some comments that the 
Imagenet2012 database had moved to a new home. However, when writing up this documentation,
I couldn't find that reference nor the new home.

In conclusion, it seems that getting the dataset is significantly less straightforward than
it should be. However, it is possible to find the dataset eventually. I think the dataset
has officially been mirrored on Kaggle: 
<https://www.kaggle.com/c/imagenet-object-localization-challenge/data>

## Using Imagenet in Tensorflow

The training and validation .tar files need to be converted into something called a 
`TFRecord` format (something used by Tensorflow I guess). This flow assumes that you have
the datasets downloaded and stored in a path `/path-to-datasets/`. Some helpful links are
provided:

* Documentation on how to get the official ResNet tensorflow models working on the
    Image net data: <https://github.com/tensorflow/models/tree/master/official/resnet>

* Documentation and script for converting the Imagenet .tar files into the form desired
    by Tensorflow: <https://github.com/tensorflow/tpu/tree/master/tools/datasets#imagenet_to_gcspy>

* The Python script that does the conversion: <https://github.com/tensorflow/tpu/blob/master/tools/datasets/imagenet_to_gcs.py>

This info should all be incorporated into the build script `build.sh`. To run it, just 
execute
```sh
./build.sh /path-to-tar-files
```
This will create the folders
```
/path-to-tar-files/train
/path-to-tar-files/validation
```
and unpack the tar files into these respective folders. The original tar files will be left
alone, so make sure you have around 300G of extra free space when you do this, otherwise 
you're gonna have a bad day.

After unpacking, the build script will execute the `imagenet_to_gcs.py` script to do the
actual conversion.

Be aware that dataset conversion can take a long time. You probably want to run the build
script in a `tmux` shell or something so you can go have a coffee.

Note that the build script will launch an docker instance of `darchr/tf-compiled-base` 
because the Python script needs Tensorflow to run. Once the script finishes, you should
be good to go.

### Changes made to `imagenet_to_gcs.py`

I had to make several changes for Python 2 to Python 3 compatibility. (Seriously folks, 
can't we all just agree to use Python 3??)

* Line 58: Commented out the `import google.cloud ...` line because we're not uploading 
    anything to the google cloud and I don't want to install that package.

* Lines 177, 179: Suffixed string literals with `''.encode()` to tell python that these 
    should by byte collections.

* Lines 187, 189: Add `.encode` to several strings to `_bytes_feature` doesn't complain.

* Line 282: Change the 'r' option in reading to 'rb'. Avoid trying to reinterpret image
    data as `utf-8`, which will definitely not work.

* Line 370: A Python `range` object is used and then shuffled. However, in Python3, ranges
    have become lazy and thus cannot be shuffled. I changed this by explicitly converting
    the `range` to a `list`, forcing materialization of the whole range.
