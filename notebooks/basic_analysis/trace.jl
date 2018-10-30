using Pkg
Pkg.activate("../../Launcher")

savefile = "plot.png"

# Dependencies
using Launcher, MemSnoop, Plots
pyplot()

cpuset = "4"
sampletime = 0.5

cnn = CifarCnn(args = (batchsize = 128, epochs = 1))
trace = run(cnn; cpuSets = cpuset) do container
    # Only read from the heap
    MemSnoop.trace(getpid(container); sampletime = sampletime)
end

# Function to generate the plots.
plot(trace::MemSnoop.Trace) = heatmap(MemSnoop.HeatmapWrapper(trace))

plt = plot(trace)
savefig(savefile)
Launcher.save("trace.jls", trace)
