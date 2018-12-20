#!/bin/bash

# Compile the LSTM op
cd /street/cc

# Had to add TF_LFLAGS, courtesy of 
# https://www.tensorflow.org/guide/extend/op#compile_the_op_using_your_system_compiler_tensorflow_binary_installation
TF_CFLAGS=( $(python -c 'import tensorflow as tf; print(" ".join(tf.sysconfig.get_compile_flags()))') )
TF_INC=$(python -c 'import tensorflow as tf; print(tf.sysconfig.get_include())')
TF_LFLAGS=( $(python -c 'import tensorflow as tf; print(" ".join(tf.sysconfig.get_link_flags()))') )
echo "Compiling LSTM op..."
g++ -D_GLIBCXX_USE_CXX11_ABI=0 -std=c++11 -shared rnn_ops.cc -o rnn_ops.so -fPIC -I $TF_INC ${TF_CFLAGS[@]} ${TF_LFLAGS[@]} -O3 -mavx -w
echo "Done Compiling."

# Execute the rest of the commands
cd /street
python3 "$@"
