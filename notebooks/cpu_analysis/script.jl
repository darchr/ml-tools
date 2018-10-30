using Serialization

serialized_file = "cnn_cpu_sweep.jls"

# Use Pkg and activate the "Launcher" environment
using Pkg
Pkg.activate("../../Launcher")

using Launcher; using MemSnoop

# Create the CNN model to use
cnn = CifarCnn(args = (batchsize = 128, epochs = 2))

# Time between sampling
sampletime = 0.5

# Configure CPU Sets
cpu_sets = ["0", "0-1", "0-3", "0-5", ""]

trackers = MemSnoop.StackTracker[]
for set in cpu_sets
    tracker = run(cnn; cpuSets = set) do container
        trackstack(getpid(container), sampletime = sampletime)
    end
    push!(trackers, tracker)
end

# Save the set of trackers to file.
Launcher.save(serialized_file, trackers)
