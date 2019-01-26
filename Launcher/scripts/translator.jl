# The goal of this script is to perform a grid search of various threading settings to try
# to find the best threading setting for Inception v4

using Pkg; Pkg.activate("..")
using Launcher
using Dates
using Checkpoints

setdepot(joinpath(@__DIR__, "translator"))

# Using all 48/96 physical/logical cores
f = Launcher.Translator
parser = Launcher.translator_parser
modelkw = Launcher.NTIter((
    workers = (0, 2, 8, 16, 24),
    max___length___train = (50, 100)
))
createkw = Launcher.NTIter((
    cpuSets = ("0-95",),
))
runtime = Minute(10)

result = @checkpoint Launcher.search(f, parser, modelkw, createkw, "temp", runtime) "96threads.checkpoint"
