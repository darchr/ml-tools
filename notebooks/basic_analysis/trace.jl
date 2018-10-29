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
function plot(trace::MemSnoop.Trace)
    # Get all of the virtual pages seen in the trace.
    all_addresses = MemSnoop.addresses(trace)

    bitmap = [MemSnoop.isactive(sample, address) for address in all_addresses, sample in trace]

    return heatmap(bitmap)
end

plt = plot(trace)
savefig(savefile)
Launcher.save("trace.jls", trace)
