#!/bin/bash
cd /brats_repo/brats

export PYTHONPATH=/brats_repo:$PYHONPATH
export PATH=/ANTs/build/bin:$PATH

python3 -c "from preprocess import convert_brats_data; convert_brats_data('/data/original', '/data/preprocessed')"
