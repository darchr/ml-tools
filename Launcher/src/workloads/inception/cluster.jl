"""
    inception_cluster(;kw...) 

Summary of Keyword arguments:

* `nworkers`: Number of worker nodes in the cluster. Default: 1

* `cpusets::Vector{String}`: The CPUs to assign to each worker. 

* `memsets::Vector{String}`: NUMA nodes to assign to each worker.
"""
function inception_cluster(;
        nworkers = 1,
        cpusets = ["0-95"],
        memsets = ["0-1"],
        kmp_blocktime = 1,
        kmp_settings = 1,
        omp_num_threads = 48,
        inter_op_threads = 2,
        intra_op_threads = 48,
    )

    workers = map(1:nworkers) do index
        # Create the worker type
        args = (
            inter_op_parallelism_threads = inter_op_threads,
            intra_op_parallelism_threads = intra_op_threads,
            num_workers = nworkers,
            worker_index = index - 1,
        )
        worker = Inception(args = args)

        # Attach environmental arguments
        kw = (
            cpuSets = cpusets[index],
            cpuMems = memsets[index],
            kmp_blocktime = kmp_blocktime,
            kmp_settings = kmp_settings,
            omp_num_threads = omp_num_threads,
        )

        return (worker, kw)
    end
    return InceptionCluster(workers)
end
