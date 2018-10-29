serialized_file = "wss_time_single.jls"

using Pkg
Pkg.activate("../../Launcher")

using Launcher, MemSnoop

# Create the CNN model to use
cnn = CifarCnn(args = (batchsize = 128, epochs = 2))

# Time intervals to test
intervals = [0.2, 0.5, 1, 2, 4, 8]
cpuset = "8" # Try to avoid clashing with an existing process.

trackers = MemSnoop.StackTracker[]

for interval in intervals
    tracker = run(cnn; interval = interval, cpuSets = cpuset)
    push!(trackers, tracker)
end

Launcher.save(serialized_file, trackers)
