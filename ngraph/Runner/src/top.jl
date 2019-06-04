# Function stubs for passing information into `entry`
using Plots
function title end
function savedir end

function entry(fns, opts; calibrate = true)
    for f in fns
        # Generate the reuse plot and heap allocation plots
        #_reuse_plot(f)
        #_allocation_plot(f)

        # Run for the product of functions and optimization targets.
        if calibrate
            for opt in opts
                iterations = calibrate(f, opt)

                @info """
                Function: $(name(f))
                Opt: $(name(opt))
                Iterations: $iterations
                """
            end
        end
        for opt in opts
            _entry(f, opt)
        end
    end
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

function _entry(f, opt)
    # Perform a profiling and calibration
    savefile = joinpath(savedir(f), join((name(f), name(opt)), "_") * ".jls")
    compare(f, opt; statspath = savefile)
    return nothing
end
