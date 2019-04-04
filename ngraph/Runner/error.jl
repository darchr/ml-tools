using Pkg; Pkg.activate(".")
using Runner, Zoo, Serialization, nGraph
Runner.setup_affinities(); Runner.setup_profiling()

println("Compiling Function")
f, args = Zoo.mnist()
