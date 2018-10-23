module Plotting

using Makie

function plot(trace::Launcher.Trace)
    pages = Launcher.allpages(trace)
    timestamps = (sort ∘ collect ∘ Launcher.times)(trace)

    references = [trace[timestamp][page] for page in pages, timestamp in timestamps]

    z = clamp.(log2.(references), 0, Inf)
    return heatmap(z)
end

end # module
