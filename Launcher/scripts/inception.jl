# The goal of this script is to perform a grid search of various threading settings to try
# to find the best threading setting for Inception v4

using Pkg; Pkg.activate("..")
using Launcher
using Dates
using Checkpoints

setdepot(joinpath(@__DIR__, "inception"))

# Using all 48/96 physical/logical cores
f = Launcher.Inception
parser = Launcher.tf_timeparser
modelkw = Launcher.NTIter((
    inter_op_parallelism_threads = (0, 2, 48),
    intra_op_parallelism_threads = (0, 48, 96),
))
createkw = Launcher.NTIter((
    omp_num_threads = (48,),
    kmp_blocktime = (0, 1, 10, 30)
))
runtime = Minute(10)

result = @checkpoint Launcher.search(f, parser, modelkw, createkw, "temp", runtime) "96threads.checkpoint"
@show result

# Using 24/48 physical/logical cores on a locked NUMA Node
f = Launcher.Inception
parser = Launcher.tf_timeparser
modelkw = Launcher.NTIter((
    inter_op_parallelism_threads = (0, 1, 24),
    intra_op_parallelism_threads = (0, 24, 48),
))
createkw = Launcher.NTIter((
    omp_num_threads = (24,),
    kmp_blocktime = (0, 1),
    cpuSets = ("0-23,48-71",),
    cpuMems = ("0",),
))
runtime = Minute(10)

result = @checkpoint Launcher.search(f, parser, modelkw, createkw, "temp", runtime) "48threads.checkpoint"
@show result
