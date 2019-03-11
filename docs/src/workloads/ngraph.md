# NGraph Models

This (eventually) will be a collection of models implemented directly in nGraph, which
will have high performance CPU models for inference and training.

## Usage From Launcher

Navigate to the `Launcher/` directory and launch Julia with
```
julia --project
```
From inside Julia, to launch resnet 50 with a batchsize of 32, use the following command:
```julia
julia> using Launcher

julia> workload = Launcher.NGraph(args = (model = "resnet50", batchsize = 64, iterations = 100))
```
Note that running for a larger number of iterations will likely yield better results.

**Valid Command Line Arguments**

```
usage: ngraph.jl [--model MODEL] [--batchsize BATCHSIZE] [--mode MODE]
                 [--iterations ITERATIONS] [-h]

optional arguments:
  --model MODEL         Define the model to use (default: "resnet50")
  --batchsize BATCHSIZE
                        The Batchsize to use (type: Int64, default:
                        16)
  --mode MODE           The mode to use [train or inference] (default:
                        "inference")
  --iterations ITERATIONS
                        The number of calls to perform for
                        benchmarking (type: Int64, default: 20)
  -h, --help            show this help message and exit
```

## Automatically Applied Arguments

These are arguments automatically supplied by Launcher.

* `--model`: resnet50

* `--mode`: inference

## Automatically Applied Environmental Veriables

Many of the nGraph parameters are controlled through environmental variables. The default
supplied by `Launcher` are:

* `NGRAPH_CODEGEN=1`: Enable code generation of models. This typically has much tighter
    runtimes than the nGraph interpreter, even if it's not necessarily faster.

**NOTE**: Right now, the functionality to add more environmental variables does not exist,
but will be exposed over time as the variables of interest are identified.
