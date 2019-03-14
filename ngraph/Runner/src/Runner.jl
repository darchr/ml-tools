module Runner

using nGraph, Flux, JSON
using Dates

include("graph.jl")

#####
##### PMEM initialization
#####

function setup_pmem(file = "/mnt/public/file.pmem", size = 2^32)
    ispath(file) && rm(file)

    manager = nGraph.Lib.getinstance()
    @show manager
    nGraph.Lib.create_pool(manager, file, convert(UInt, size))
    return nothing
end

#####
##### Setup Affinities
#####

function setup_affinities()
    ENV["KMP_AFFINITY"] = "compact,granularity=fine"
    
    # Use the first 24 cores - 2 threads for each core, 0 offset (numanode 0)
    ENV["KMP_HW_SUBSET"] = "24c,2t"

    # 1 Thread for each core
    ENV["OMP_NUM_THREADS"] = 48
    #ENV["OMP_PROC_BIND"] = true
end

teardown_affinities() = delete!.(Ref(ENV), ("KMP_AFFINITY", "KMP_HW_SUBSET", "OMP_NUM_THREADS"))

function setup_profiling()
    nGraph.enable_codegen()
    nGraph.enable_timing()
end

#####
##### Example Network Building
#####

function _network(x)
    # Construct a conv followed by a max pool
    chain = Chain(
        Conv((3, 3), size(x, 3) => 128, relu; pad = (1, 1)),
        x -> maxpool(x, (3, 3); stride = (1, 1)),
        x -> reshape(x, :,  size(x, 4))
    )

    # Perform this operation
    y = chain(x) 

    # Get the size of `x` and use that to construct a `Dense` layer
    return softmax(Dense(size(y, 1), 10, relu)(y))
end

function simple_network()
    # Instantiate the nGraph backend object
    backend = nGraph.Backend()

    batchsize = 8
    nchannels = 16

    # Create a nGraph tensor
    X = nGraph.Tensor(backend, rand(Float32, 20, 20, nchannels, batchsize))

    f = nGraph.compile(backend, _network, X)

    # Return the arguments as a tuple so in the future, we can return multiple compiled 
    # function arguments and still have downstream code work.
    return f, (X,)
end

_skip(op) = in(nGraph.description(op), ("Parameter", "Constant", "Result"))
keep(op) = !_skip(op)

@enum TensorLocation::UInt8 DRAM PMEM

struct NodeConfig{N, M}
    inputs::NTuple{N, TensorLocation}
    outputs::NTuple{M, TensorLocation}
end

# Steps
#
# - Get all of the op names
# - Build datastructures:
#
#       * Node Names -> Node
#       * Node Names -> Inputs and Outputs
#       * Data structure mappint Node Name + I/O PMEM state to times
#
#   This last data structure we will use for setting the states of internal variables as 
#   well as selecting the next state to explore.
#
# NOTE: We should skip "constants" as we don't yet have the technology to map these into
# PMEM.
function memory_profile(fex::nGraph.FluxExecutable, args)
    # I've hacked the compiler chain with an environmental variable to disable running
    # most of the compilation passes.
    #
    # The only passes that get run if this environmental variable is defined is the
    # MemoryAllocation pass
    #
    # This SHOULD let us recompile a function without a bunch of extra nodes getting 
    # inserted.
    ENV["NGRAPH_PASS_HACK"] = 1
    setup_profiling()
    local x
    try
        x = _memory_profile(fex, args)
    finally
        delete!(ENV, "NGRAPH_PASS_HACK")
    end
    return x
end

function _memory_profile(fex::nGraph.FluxExecutable, args)
    setup_pmem()

    # Unpack the function
    ngraph_function = fex.ex.ngraph_function

    #graph = ExtractedGraph(ngraph_function)
    graph = Dict(nGraph.name(op) => op for op in ngraph_function) 

    # Now we start doing timings
    #
    # Because large nGraph functions can take a while to compile (seconds - 10s of seconds),
    # we have to get as much milage out of each profiling run as possible.
    #
    # The general idea is 
    #   - generate all of the configurations we want to run for the whole profile
    #   - pick a configuration that has not been tested yet, use that as an assignment
    #       and capture all of the nodes participating in that transaction.
    #
    #   - Keep picking configurations until we can't pick another configuration without
    #       interfering with another configuration. 
    #
    #   - Then, compile the function and get all of the profiling information.
    remaining_configs = Set{Tuple{String, NodeConfig}}()
    results = Dict(
        nGraph.name(op) => Dict{NodeConfig, Float64}() 
        for op in ngraph_function
        if keep(op)
    )

    for op in ngraph_function
        if keep(op)
            # Get the number of inputs and outputs for the op
            ninputs = nGraph.get_input_size(op)
            noutputs = convert(Int, nGraph.get_output_size(op))

            op_name = nGraph.name(op)

            # Build up a list of iterators for the inputs. For inputs that are `ops` that
            # we want to skip, only let them be DRAM
            input_configs = [
                 keep(input) ? (PMEM, DRAM) : (DRAM,) 
                 for input in nGraph.get_inputs(op)
            ]

            # TODO: Clean up this API
            output_configs = [
                nGraph.Lib.output_is_result(op.ptr, i-1) ? (DRAM,) : (PMEM, DRAM) 
                for i in 1:noutputs
            ]

            for input_config in Iterators.product(input_configs...)
                for output_config in Iterators.product(output_configs...)
                    config = NodeConfig(input_config, output_config)
                    push!(remaining_configs, (op_name, config))
                end
            end
        end
    end

    @info "Testing $(length(remaining_configs)) total configurations"

    loop_counter = 0
    while !isempty(remaining_configs)
        @info "Configurations Left: $(length(remaining_configs))"

        # Keep track of the nodes that are being tested so we don't overlap
        seen = Set{String}()
        
        for (name, config) in remaining_configs
            # Abort if this node is already being tested
            in(name, seen) && continue

            # Abort if any neighbors of this node are under test
            inputs = nGraph.get_inputs(graph[name]) 
            outputs = Iterators.flatten(nGraph.get_outputs(graph[name]))
            neighbors = Iterators.flatten((inputs, outputs))
            any(in(seen), nGraph.name.(neighbors)) && continue

            # Set the config for the parent node and mark tha parent + all neighbors as seen
            # so the config is not overwritten
            _setup!(graph[name], config)
            push!(seen, name)
            for neighbor in neighbors
                push!(seen, nGraph.name(neighbor))
            end
        end

        # Run the profiling
        fex = _profile(fex, args)
        tally!(results, fex, graph)

        # Get all the configs present in the graph and clear them from the remaining configs
        for op in ngraph_function
            config = getconfig(op)
            name = nGraph.name(op)

            delete!(remaining_configs, (name, config))
        end
        map(_cleanup!, ngraph_function)
        loop_counter += 1
    end

    @info "Profiling took $loop_counter iterations"

    return results
end

function _profile(fex, args; runtime = Millisecond(3000))
    fex = nGraph.recompile(nGraph.Backend(), fex)
    time = now()
    while now() < time + runtime
        fex(args...)
    end
    return fex
end

function tally!(results::Dict{String, Dict{NodeConfig, Float64}}, fex, graph)
    f = fex.ex.ngraph_function

    function_name = nGraph.name(f)
    timings = JSON.parsefile("$function_name.timeline.json")["traceEvents"]

    # Slurp up all the results that haven't been seen yet.
    for (node_name, result_dict) in results
        # Record the time for this config.
        config = getconfig(graph[node_name])

        # Get the timing and record it
        index = findfirst(x -> x["name"] == node_name, timings)
        @assert index !== nothing
        time = timings[index]["dur"]

        result_time = min(time, get(result_dict, config, typemax(time)))
        result_dict[config] = result_time
    end
end

function getconfig(n::nGraph.Node)
    input = Tuple(nGraph.is_persistent(nGraph.input_descriptor(n, i)) ? PMEM : DRAM 
                  for i in 1:nGraph.get_input_size(n))
    output = Tuple(nGraph.is_persistent(nGraph.output_descriptor(n, i)) ? PMEM : DRAM 
                  for i in 1:nGraph.get_output_size(n))

    return NodeConfig(input, output)
end

reset!(fex) = map(_cleanup!, fex.ex.ngraph_function)

#####
##### Setup and cleanup code
#####

function _setup!(node::nGraph.Node, config::NodeConfig)
    # Configure all the outputs - those are easy
    for (i, location) in enumerate(config.outputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.output_descriptor(node, i))
        end
    end

    # Now for the inputs
    for (i, location) in enumerate(config.inputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.input_descriptor(node, i))
        end
    end
end

# Set everything back to volatile
function _cleanup!(node::nGraph.Node)
    for i in 1:nGraph.get_output_size(node)
        nGraph.make_volatile(nGraph.output_descriptor(node, i))
    end

    for i in 1:nGraph.get_input_size(node)
        nGraph.make_volatile(nGraph.input_descriptor(node, i))
    end
end

end # module
