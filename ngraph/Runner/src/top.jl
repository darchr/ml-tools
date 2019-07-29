# Function stubs for passing information into `entry`
using Plots
function title end
function savedir end

function entry(fns, opts, backend; kw...)
    for f in fns, opt in Iterators.flatten(opts)
        _entry(f, opt, backend; kw...)
    end
end

function entry(fns, opt::AbstractOptimizer, backend; kw...)
    for f in fns
        _entry(f, opt, backend; kw...)
    end
end

# Entry points
function _entry(f, opt, backend; kw...)
    # Perform a profiling and calibration
    savefile = joinpath(savedir(f), join((name(f), name(opt)), "_") * ".jls")
    compare(f, opt, backend; statspath = savefile, kw...)
    return nothing
end

function _entry(f, opt::Numa, backend)
    savefile = joinpath(savedir(f), join((name(f), "numa"), "_") * ".jls")

    if !ispath(savefile)
        stats = _base_stats()
        initialize!(stats, f, backend)
    else
        stats = deserialize(savefile)
    end

    fex, limit = run_numa(backend, f, opt)
    runtime = gettime(fex)

    run = Dict(
        :dram_limit => limit,
        :actual_runtime => runtime,
        :dram_alloc_size => 
            convert(Int, nGraph.get_temporary_pool_size(fex.ex.ngraph_function)),
        :pmem_alloc_size => 
            convert(Int, nGraph.get_pmem_pool_size(fex.ex.ngraph_function)),
    )

    push!(stats.runs, run)
    sort!(stats.runs; rev = true, by = x -> x[:dram_limit])
    serialize(savefile, stats)
end

function _entry(f, opt::Optimizer2LM, backend::nGraph.Backend{nGraph.CPU})
    savefile = joinpath(savedir(f), join((name(f), "numa"), "_") * ".jls")

    stats = ispath(savefile) ? deserialize(savefile) : _base_stats()
    fex = actualize(backend, f)
    runtime = gettime(fex)

    run = Dict(
        :actual_runtime => runtime,
    )

    push!(stats.runs, run)
    serialize(savefile, stats)
end

#####
##### Misc stuff
#####

function _allocation_plot(f)
    fex, args = f()

    plt = plot(AllocationView(), fex, title = name(f))
    savefile = joinpath(savedir(f), name(f) * "_allocation_plot.png")
    png(plt, savefile)
end


