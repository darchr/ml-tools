module Runner

using nGraph, Flux, JSON
using Dates

include("serializer.jl")

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

    # Intermediate files are generated from the function name. We grap that here so we know
    # what to look for later
    function_name = nGraph.name(ngraph_function)

    # Iterate through all of the ops in nGraph
    node_map = Dict{String, nGraph.Node}()

    etype = NamedTuple{(:node, :index), Tuple{nGraph.Node, Int}}
    input_map = Dict{String, Vector{etype}}()

    # Note: due to the way nGraph is constructed, each output from a node can have multiple
    # users. Thus, to construct the output node map, we first construct the input node map
    # and then traverse it.

    for op in ngraph_function
        op_name = nGraph.name(op)
        
        # Here, we get a tuple with a Node and an index.
        #
        # The node input node for this input of the graph and the index is the output
        # index that this node references.
        input_tuples = nGraph.get_inputs(op)

        # Do some doctoring to get the convert the returned tuple to a named tuple for
        # slightly nices processing
        inputs = map(x -> (node = first(x), index = last(x)), input_tuples)

        # Save a bunch of metadata
        node_map[op_name] = op
        input_map[op_name] = inputs
    end

    results = Dict{String, Dict{NodeConfig, Float64}}()

    # Now we start doing timings
    for i in 1:length(ngraph_function)
        op = ngraph_function[i]
        println()
        println()
        println("$i of $(length(ngraph_function)). Op Name: $(nGraph.name(op))")
        if keep(op)
            # Get the number of inputs and outputs for the op
            ninputs = nGraph.get_input_size(op)
            noutputs = convert(Int, nGraph.get_output_size(op))

            op_name = nGraph.name(op)
            @show nGraph.name.(i.node for i in input_map[op_name])
            println()

            # Build up a list of iterators for the inputs. For inputs that are `ops` that
            # we want to skip, only let them be DRAM
            input_configs = [keep(input.node) ? (PMEM, DRAM) : (DRAM,) for input in input_map[op_name]]
            output_configs = [nGraph.Lib.output_is_result(op.ptr, i-1) ? (DRAM,) : (PMEM, DRAM) for i in 1:noutputs]

            local_results = Dict{NodeConfig, Float64}() 

            for input_config in Iterators.product(input_configs...)
                for output_config in Iterators.product(output_configs...)
                    @show input_config
                    @show output_config

                    config = NodeConfig(input_config, output_config)
                    fex, time = _profile(fex, args, op, config)

                    local_results[config] = time
                end
            end

            results[op_name] = local_results
        end
    end

    return results
end

function _profile(fex, args, node::nGraph.Node, config::NodeConfig; runtime = Millisecond(100))
    _setup!(node, config)

    backend = nGraph.Backend()
    fex = nGraph.recompile(backend, fex)
    # Run for `runtime` seconds then take a measurement
    time = now() 
    while now() < time + runtime
        fex(args...)
    end

    # Get the function name
    function_name = nGraph.name(fex.ex.ngraph_function)
    timings = JSON.parsefile("$function_name.timeline.json")

    # Look up the timing for this node and return it
    index = findfirst(x -> x["name"] == nGraph.name(node), timings["traceEvents"])
    time = timings["traceEvents"][index]["dur"]

    _cleanup!(node)
    return fex, time
end

#####
##### Setup and cleanup code
#####

function _setup!(node::nGraph.Node, config::NodeConfig)
    # Configure all the outputs - those are easy
    for (i, location) in enumerate(config.outputs)
        if location == PMEM
            tensor_ptr = nGraph.Lib.get_output_tensor_ptr(node.ptr, i-1)
            nGraph.Lib.make_persistent(tensor_ptr)
        end
    end

    # Now for the inputs
    for (i, location) in enumerate(config.inputs)
        if location == PMEM
            input_node, index = nGraph.get_input(node, i)
            _skip(input_node) && continue
            tensor_ptr = nGraph.Lib.get_output_tensor_ptr(input_node.ptr, convert(Int, index-1))
            nGraph.Lib.make_persistent(tensor_ptr)
        end
    end
end

# Set everything back to volatile
function _cleanup!(node::nGraph.Node)
    for i in 1:nGraph.get_output_size(node)
        tensor_ptr = nGraph.Lib.get_output_tensor_ptr(node.ptr, convert(Int, i-1))
        nGraph.Lib.make_volatile(tensor_ptr)
    end

    for i in 1:nGraph.get_input_size(node)
        input_node, index = nGraph.get_input(node, i)
        tensor_ptr = nGraph.Lib.get_output_tensor_ptr(input_node.ptr, convert(Int, index-1))
        nGraph.Lib.make_volatile(tensor_ptr)
    end
end

end # module
