#####
##### PMEM initialization
#####

function setup_pmem(dir = "/mnt/public/")
    if isdir(dir) 
        for file in readdir(dir)
            rm(joinpath(dir, file); recursive = true)
        end
    end

    manager = nGraph.Lib.getinstance()
    nGraph.Lib.set_pool_dir(manager, dir)
    return nothing
end

#####
##### Setup Affinities
#####

function setup_affinities()
    ENV["KMP_AFFINITY"] = "compact,granularity=fine"

    # Use the first 24 cores - 2 threads for each core
    # Send to numa-node 1 for a hopefully more quiet system
    #
    # See docs/runner/kmp.md for syntax documentation
    ENV["KMP_HW_SUBSET"] = "1s@1,1t"

    # 1 Threads for each core
    ENV["OMP_NUM_THREADS"] = 24
end

teardown_affinities() = delete!.(Ref(ENV), ("KMP_AFFINITY", "KMP_HW_SUBSET", "OMP_NUM_THREADS"))

function setup_profiling()
    nGraph.enable_codegen()
    nGraph.enable_timing()
end
