# Run a basic CNN for 2 epocs. Use to get a baseline understanding of the memory
# behavior
using Serialization

sample_file = "docker.jls"
python_file = "python.jls"
serialized_file = "cifar_cnn_basic.jls"

using Pkg
Pkg.activate("../../Launcher")

using Launcher, MemSnoop


# Time interval between samples
sampletime = 0.2
fine_sampletime = 0.1
cpuset = "4" # Set to a high number to hopefully avoid clashing with anything

# First, just launch the given container to a shell
cnn = CifarCnn(interactive = true)
nsamples = 40

tracker = run(cnn; cpuSets = cpuset) do container
    trackstack(getpid(container), sampletime = sampletime, iter = 1:nsamples)
end
Launcher.save(sample_file, tracker)

# Next, get a trace of what happens if we just pass "abort" argument, launching python
# but not actually running training.
cnn = CifarCnn(args = (abort = nothing,))
tracker = run(cnn; cpuSets = cpuset) do container
    trackstack(getpid(container), sampletime = sampletime)
end
Launcher.save(python_file, tracker)

# Now generate the actual trace
cnn = CifarCnn(args = (batchsize = 128, epochs = 2))
tracker = run(cnn; cpuSets = cpuset) do container
    trackstack(getpid(container), sampletime = sampletime)
end

Launcher.save(serialized_file, tracker)
