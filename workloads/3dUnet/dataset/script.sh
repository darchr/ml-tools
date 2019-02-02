#!/bin/bash
cd /brats_repo/brats
python3 -c "from preprocess import convert_brats_data; convert_brats_data('/data/original', '/data/preprocessed')"
