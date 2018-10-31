# Notebooks

The notebooks in this repo contain plots and run scripts to generate the data for those 
plots. The contents of the notebooks are summarized here and contain links to the rendered
notebooks are included.

In general, each directory contains a notebook and a collection of scripts. Since
`sudo` access is needed to run `MemSnoop`, these scripts are stand-alone. 

Note that these scripts should be run before the notebooks if trying to recreate the plots.

## [Basic Analysis](https://github.com/darchr/ml-notebooks/blob/master/basic_analysis/basic_analysis.ipynb)

Basic analysis of the memory usage during the training of a simple CNN on a single CPU. The
sampling window was 0.2 seconds. That is, the sampling procedure went something like this:

1. Mark all the applications pages as idle.
2. Run application for 0.2 seconds
3. Pause application
4. Determine which pages are active and update data structures.
5. Repeat

Plots included in this section:

1. WSS estimation for a single threaded process.
2. Reuse distance analysis.
3. Verification that Docker and Python are not interfering with the measurements.
4. Heatmap plots visualizing the memory access patterns to the Python heap and for the whole
    application during 1 epoch of training.


## [CPU Analysis](https://github.com/darchr/ml-notebooks/blob/master/cpu_analysis/cpu_analysis.ipynb)

Plots and some analysis of how the memory requirements and training speed for 2 epochs of 
training scale as the number of available processors is increased.

## [Batchsize](https://github.com/darchr/ml-notebooks/blob/master/batchsize/batchsize.ipynb)

Data on how WSS and Reuse Distance vary with training batch size. Parameters of experiment:

    * Small CNN on Cifar10 dataset
    * Single thread
    * Unlimited memory
    * 0.5 second sampletime
    * 1 epoch of training
    * Batchsizes: 16, 32, 64, 128, 256, 512, 1024

I'm not entirely sure what that data means yet ...

## [Filters](https://github.com/darchr/ml-notebooks/blob/master/filters/filters.ipynb)

The goal of this experiment is to see if we can filter out some types of memory during the
trace without significantly affecting the results. Filtering out some regions of memory can
speed up the idle page tracking process and reduce the memory footprint of the snooper.

In particular, I explore filtering out Virtual Memory Areas (VMAs) that are

    * Executable
    * Neither readable nor writable
    * Smaller than 4 pages

**Conclusion** - It's probably okay to do this. However, I need to try this on non single
threaded models just in case.

## [Sample Time](https://github.com/darchr/ml-notebooks/blob/master/wss_time/wss_estimate_sensitivity.ipynb)

Experiment to investigate how sensitive our estimates of WSS and Reuse Distance are to
the sample time. Parameters of the experiment:

    * Small CNN on Cifar dataset
    * Both single threaded and with 12 threads
    * Sample times of 0.2, 0.5, 1, 2, 4, and 8 seconds
    * Batch size of 128
    * Training for 1 epoch

