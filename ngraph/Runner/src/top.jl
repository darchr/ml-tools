# Function stubs for passing information into `entry`
using Plots
function title end
function savedir end

function entry(fns, opts, backend)
    for f in fns
        # Generate the reuse plot and heap allocation plots
        #_reuse_plot(f)
        #_allocation_plot(f)

        # Run for the product of functions and optimization targets.
        # for (opt, _calibrate) in zip(opts, calibrations)
        #     _calibrate || continue

        #     for o in opt
        #         iterations = calibrate(f, o)

        #         @info """
        #         Function: $(name(f))
        #         Opt: $(name(o))
        #         Iterations: $iterations
        #         """
        #     end
        # end
        for opt in Iterators.flatten(opts)
            _entry(f, opt, backend)
        end
    end
end

function _entry(f, opt, backend)
    # Perform a profiling and calibration
    savefile = joinpath(savedir(f), join((name(f), name(opt)), "_") * ".jls")
    compare(f, opt, backend; statspath = savefile)
    return nothing
end

function _reuse_plot(f)
    # Instantiate the function, make the profile data and get the title
    fex, args = f()
    p = ProfileData(fex)
    title = name(f)

    # Generate and save the plot
    plt = plot(ReusePlot(), p, title = title)
    savefile = joinpath(savedir(f), name(f) * "_reuse_plot.png")
    png(plt, savefile)
    return nothing
end

function _allocation_plot(f)
    fex, args = f()

    plt = plot(AllocationView(), fex, title = name(f))
    savefile = joinpath(savedir(f), name(f) * "_allocation_plot.png")
    png(plt, savefile)
end

#####
##### TODO: Need a manager module to manage all of these experiments!!
#####
function entry_numa(backend, funcs, limits)
    for f in funcs, limit in limits
        savefile = joinpath(savedir(f), join((name(f), "numa"), "_") * ".jls")

        if !ispath(savefile)
            stats = []
        else
            stats = deserialize(savefile)
        end

        fex = run_numa(backend, f, limit)
        runtime = gettime(fex)

        stat = Dict(
            :dram_limit => limit,
            :actual_runtime => runtime,
        )
        push!(stats, stat)
        sort!(stats; rev = true, by = x -> x[:dram_limit])
        serialize(savefile, stats)
    end
end
