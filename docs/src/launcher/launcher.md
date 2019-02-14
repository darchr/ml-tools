# Tutorial

Launcher is the Julia package for handling the launching of containers, aggregation of 
results, binding containers with relevant datasets, and generally making sure everything is 
working correctly. (And if it isn't working correctly, please open a GitHub issue :D)

## Basic Example

The workloads are all up into individual workloads, each of which has their own documentation.
Below is an example of running Resnet 50:
```
cd Launcher
julia --project
```
Inside the Julia REPL:
```julia
julia> using Launcher

julia> workload = Slim(args = (model_name = "resnet_v1_50", batchsize = 32))
Slim
  args: NamedTuple{(:model_name, :batchsize),Tuple{String,Int64}}
  interactive: Bool false

julia> run(workload)
```
This will create a docker container running Resnet 50 that will keep running until you
interrupt it with `ctrl + C`.

## Saving Output Log to a File

To run a workload and save the stdout to a file for later analysis, you may pass an open
file handle as the `log` keyword of the `run` function:

```julia
julia> using Launcher

julia> workload = Slim(args = (model_name = "resnet_v1_50", batchsize = 32))

# Open `log.txt` and pass it to `run`. When `run` exists (via `ctrl + C` or other means),
# the container's stdout will be saved into `log.txt`.
julia>  open("log.txt"; write = true) do f
            run(workload; log = f)
        end
```

## Running a Container for X seconds

The [`run`](@ref) function optionally accepts an arbitrary function as its first argument,
to which it passes a handle to the Docker container is created. This lets you do anything
you want with the guarentee that the container will be successfully cleaned up if things
go south. If you just want to run the container for a certain period of time, you can
do something like the following:

```julia
julia> using Launcher

julia> workload = Slim(args = (model_name = "resnet_v1_50", batchsize = 32))

# Here, we use Julia's `do` syntax to implicatly pass a function to the first
# argument of `run`. In this function, we sleep for 10 seconds before returning. When we
# return, the function `run` exits.
julia>  run(workload) do container
            sleep(10)
        end
```

## Gathering Performance Metrics

One way to gather the performance of a workload is to simply time how long it runs for.
```julia
julia> runtime = @elapsed run(workload)
```
However, for long running workloads like DNN training, this is now always feasible. Another
approach is to parse through the container's logs and use its self reported times. There
are a couple of functions like [`Launcher.tf_timeparser`](@ref) and 
[`Launcher.translator_parser`](@ref) that provide this functionality for Tensorflow and 
PyTorch based workloads respectively. See the docstrings for those functions for what 
exactly they return. Example useage is shown below.
```julia
julia> workload = Launcher.Slim(args = (model_name = "resnet_v1_50", batchsize = 32))

julia>  open("log.txt"; write = true) do f
            run(workload; log = f) do container
                sleep(120)
            end
        end

julia> mean_time_per_step = Launcher.tf_timeparser("log.txt")
```

## Passing Commandline Arguments

Many workloads expose commandline arguments. These arguments can be passed from launcher
using the `args` keyword argument to the workload constructor, like the
```
args = (model_name = "resnet_v1_50", batchsize = 32)
```
Which will be turned into
```
--model_name=resnet_v1_50 --batchsize=32
```
when the script is invoked. In general, you will not have to worry about whether the result
will be turned into `--arg==value` or `--arg value` since that is taken care of in the
workload implementations. Do note, however, that using both the `=` syntax and
space delimited syntax is not supported.

If an argument has a hyphen `-` in it, such as `batch-size`, this is encoded in Launcher
as a triple underscore `___`. Thus, we would encode `batch-size=32` as
```
args = (batch___size = 32,)
``` 


## Advanced Example

Below is an advanced example gathering performance counter data for a running workload.

```julia
# Install packages
julia> using Launcher, Pkg, Serialization, Dates

julia> Pkg.add("https://github.com/hildebrandmw/SystemSnoop.jl")

julia> using SystemSnoop

julia> workload = Slim(args = (model_name = "resnet_v1_50", batchsize = 32))

# Here, we use the SystemSnoop package to provide the monitoring using the `trace` funciton
# in that package.
julia>  data = open("log.txt"; write = true) do f 
            # Obtain Samples every Second
            sampler = SystemSnoop.SmartSample(Second(1))

            # Collect data for 5 minutes
            iter = SystemSnoop.Timeout(Minute(5))

            # Launch the container. Get the PID of the container to pass to `trace` and then
            # trace.
            data = run(workload; log = f) do container
                # We will measure the memory usage of our process over time.
                measurements = (
                    timestamp = SystemSnoop.Timestamp(),
                    memory = SystemSnoop.Statm(),
                )
                return trace(getpid(container), measurements; iter = iter, sampletime = sampler)
            end
            return data
        end

# We can plot the memory usage over time from the resulting data
julia> Pkg.add("UnicodePlots"); using UnicodePlots

julia> lineplot(getproperty.(data.memory, :resident))
           ┌────────────────────────────────────────┐
   2000000 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⡀⡀⠀⠀⠀⠀⠀⠀⠀⣀⡀⢀⣀⣀⡀⣀⣀⣀⡀│
           │⠀⠀⠀⢰⠊⠉⠉⠉⠉⠉⠁⠈⠈⠁⠀⠀⠉⠉⠁⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀⠉⠉⠉⠀⠉⠈⠁⠈⠉│
           │⠀⠀⠀⣸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⢠⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⠀⡼⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           │⠀⡖⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
         0 │⠴⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
           └────────────────────────────────────────┘
           0                                      300

# We can save the `data` datastructure for later using
julia> serialize("my_data.jls", data)

# Finally, we can analyze the mean time per step
julia> Launcher.tf_timeparser("log.txt")
8.042285714285715
```
