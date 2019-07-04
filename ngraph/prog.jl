using Pkg; Pkg.activate(".")
using nGraph, Runner, Zoo

fex, data = Runner.gpu_factory(() -> Zoo.resnet_training(Zoo.Resnet50(), 16; backend = nGraph.Backend("GPU")));

try
    read(fex())
catch e
    println("Initial error. Yay")
end

@time read(fex())
@time read(fex())
@time read(fex())

sleep(1)
