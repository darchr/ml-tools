# Run a basic CNN for 2 epocs. Use to get a baseline understanding of the memory
# behavior
using Serialization
serialized_file = "cifar_cnn_basic.jls"

using Pkg
Pkg.activate("../../Launcher")

using Launcher, MemSnoop

cnn = CifarCnn(args = (batchsize = 128, epochs = 2))

# Time interval between samples
interval = 0.2
cpuset = "4" # Set to a high number to hopefully avoid clashing with anything

# Launch the workload and gather a trace of memory behavior
tracker = run(cnn; interval = interval, cpuSets = cpuset)

open(io -> serialize(io, tracker), serialized_file, "w")
