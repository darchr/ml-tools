serialized_file = "cifar_cnn_batch.jls"

using Pkg
Pkg.activate("../../Launcher")

using Launcher, MemSnoop

batchsizes = (16, 32, 64, 128, 256, 512, 1024)

# Create the CNN model to use
cnn = CifarCnn(args = (batchsize = 128, epochs = 2))

# Time intervals to test
interval = 0.5
cpuset = "8" # Try to avoid clashing with an existing process.

trackers = MemSnoop.StackTracker[]

for batchsize in batchsizes
    cnn = CifarCnn(args = (batchsize = batchsize, epochs  = 2))
    tracker = run(cnn; interval = interval, cpuSets = cpuset)
    push!(trackers, tracker)
end

Launcher.save(serialized_file, trackers)
