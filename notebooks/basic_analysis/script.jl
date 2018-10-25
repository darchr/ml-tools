using Serialization

serialized_file = "cnn_cpu_sweep.jls"

# Use Pkg and activate the "Launcher" environment
using Pkg
Pkg.activate("../../Launcher")

using Launcher; using MemSnoop

# Create the CNN model to use
cnn = CifarCnn(args = (batchsize = 128, epochs = 2))
