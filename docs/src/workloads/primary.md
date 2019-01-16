# Primary Workloads

These are the workloads that we will primarily use for benchmarking. These are large 
benchmarks with large memory requirements so will be good stress tests.

## Vgg416

Inspired by the vDNN paper, we use Vgg416, which is essentially Vgg16 but with 80 extra
convolution layers in each of the 5 convolution layer groups (for a total of 400 extra 
layers). From the vDNN paper, there is some precedent for this. To run this benchmark, do
the following from `Launcher`
```julia
julia> using Launcher

julia> workload = Launcher.Slim(args = (model_name = "vgg_416", batchsize = 32))
Launcher.Slim
  args: NamedTuple{(:batchsize, :model_name),Tuple{Int64,String}}
  interactive: Bool false

julia run(workload)
```
The normal command-line arguments for the `Slim` workloads also apply to this model, so feel
free to play with the parameters.
