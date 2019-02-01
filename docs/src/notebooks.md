# Notebooks

The notebooks in this repo contain plots and run scripts to generate the data for those 
plots. The contents of the notebooks are summarized here and contain links to the rendered
notebooks are included.

In general, each directory contains a notebook and a collection of scripts. Since
`sudo` access is needed to run `SystemSnoop`, these scripts are stand-alone. 

Note that these scripts should be run before the notebooks if trying to recreate the plots.

## [Performance Counter Check](https://github.com/darchr/ml-notebooks/blob/master/toolchecking/performance_counters/performance_counters.ipynb)

Validation that our hooks into hardware performance counters return sensible results.

## [Basic Analysis](https://github.com/darchr/ml-notebooks/blob/master/toolchecking/basic_analysis/basic_analysis.ipynb)

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
