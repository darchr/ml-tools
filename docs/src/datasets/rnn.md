# RNN Translator

This is the dataset for the project originally belonging to ML-Perf. The exact link to the
project is: <https://github.com/mlperf/training/tree/master/rnn_translator>. 

To install this dataset, simply run
```
ml-tools/datasets/rnn_translator/download_dataset.sh [dataset directory]
```

## Changes made to the download script

At the end of the script (lines 172 to 175), I added the following:
```
# Move everything in the output dir into the data dir
mv ${OUTPUT_DIR}/*.de ${OUTPUT_DIR_DATA}
mv ${OUTPUT_DIR}/*.en ${OUTPUT_DIR_DATA}
mv ${OUTPUT_DIR}/*.32000 ${OUTPUT_DIR_DATA}
```
It seems that the `verify_dataset.sh` script expects these files to be in the `data/` 
subdirectory, so this automates that process.

**Note**

The `verify_dataset.sh` script should be run in the top level directory where the dataset was
downloaded to because of hard coded paths.
