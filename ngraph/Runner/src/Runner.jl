module Runner

using nGraph, Flux, JSON
using Dates, Statistics

include("setup.jl")
include("opt/opt.jl")
include("models/simple.jl")

keep(op_description::String) = !in(op_description, ("Parameter", "Constant", "Result"))
keep(op::nGraph.Node) = keep(nGraph.description(op))

@enum TensorLocation::UInt8 DRAM PMEM

struct IOConfig{N, M}
    inputs::NTuple{N, TensorLocation}
    outputs::NTuple{M, TensorLocation}
end

function Base.show(io::IO, config::IOConfig{N,M}) where {N,M}
    f = x -> (x == DRAM) ? "DRAM" : "PMEM"
    print(io, "IOConfig{$N,$M}: ")
    print(io, "(", join(f.(config.inputs), ", "), ") -- ")
    print(io, "(", join(f.(config.outputs), ", "), ")")
end

struct TensorData
    name::String
    bytes::Int64
    locations::Vector{TensorLocation}
end

function TensorData(tensor::nGraph.TensorDescriptor)
    return TensorData(
        nGraph.get_name(tensor),
        sizeof(tensor),
        TensorLocation[], 
    )
end

# We pull all this information out of nGraph so we can serialize it properly.
#
# Serializing anything with nGraph references leads to a really bad time.
struct NodeData
    name::String
    description::String
    input_tensors::Vector{String}
    output_tensors::Vector{String}

    # Results from profiling
    timings::Dict{IOConfig, Vector{Float64}}
    run_numbers ::Dict{IOConfig, Vector{Int64}}
end

function NodeData(node::nGraph.Node)
    return NodeData(
        nGraph.name(node),
        nGraph.description(node),
        nGraph.get_name.(nGraph.input_descriptors(node)),
        nGraph.get_name.(nGraph.output_descriptors(node)),
        Dict{IOConfig, Vector{Float64}}(),
        Dict{IOConfig, Vector{Float64}}(),
    )
end

struct ProfileData
    tensors::Dict{String, TensorData}

    # Stored in program order.
    nodes::Vector{NodeData}

    # Liveness Analysis
    newlist::Vector{Vector{String}}
    freelist::Vector{Vector{String}}
end

function ProfileData(fn::nGraph.NFunction)
    # Construct the tensors and nodes fields
    tensors = Dict{String, TensorData}()
    nodes = NodeData[]
    for op in fn
        push!(nodes, NodeData(op))
        for tensor in nGraph.output_descriptors(op)
            @assert !haskey(tensors, nGraph.get_name(tensor))
            tensor_data = TensorData(tensor)
            tensors[tensor_data.name] = tensor_data
        end
    end

    # How, perform the liveness analysis on the nodes and tensors data structures
    liveness = liveness_analysis(nodes)

    return ProfileData(
        tensors,
        nodes,
        liveness.new_list,
        liveness.free_list
    )
end

function liveness_analysis(nodes::Vector{NodeData})
    new_list = [String[] for _ in nodes]
    free_list = [String[] for _ in nodes]

    # Forward Pass
    for (index, op) in enumerate(nodes)
        new_list[index] = op.output_tensors
    end

    # Backward Pass
    freed_tensors = Set{String}() 
    for (index, op) in enumerate(reverse(nodes))
        for tensor in op.input_tensors
            if !in(tensor, freed_tensors)
                push!(free_list[end + 1 - index], tensor)
                push!(freed_tensors, tensor)
            end
        end
    end

    return (new_list = new_list, free_list = free_list)
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
function memory_profile(fex::nGraph.FluxExecutable, args; kw...)
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
        x = _memory_profile(fex, args; kw...)
    finally
        delete!(ENV, "NGRAPH_PASS_HACK")
    end
    return x
end

function _memory_profile(fex::nGraph.FluxExecutable, args; max_simultaneous_configs = typemax(Int64))
    setup_pmem()

    # Unpack the function
    ngraph_function = fex.ex.ngraph_function
    name_to_node = Dict(nGraph.name(op) => op for op in ngraph_function)

    data = ProfileData(ngraph_function)

    # Determine the possible locations for intermediate tensors
    for op in ngraph_function
        for (index, descriptor) in enumerate(nGraph.output_descriptors(op))
            tensor_name = nGraph.get_name(descriptor)
            # If the op is a Constant or Parameter, then the output tensor can only
            # live in DRAM (for now)
            if in(nGraph.description(op), ("Constant", "Parameter"))
                push!(data.tensors[tensor_name].locations, DRAM)

            # Likewise, is a user of this output tensor is a `Result` node, the
            # tensor can only live in DRAM
            elseif nGraph.Lib.output_is_result(op.ptr, index - 1)
                push!(data.tensors[tensor_name].locations, DRAM)

            # Finally, generic tensors can live in either DRAM or PMEM
            else
                push!(data.tensors[tensor_name].locations, DRAM, PMEM)
            end
        end
    end

    # Sanity checks
    for tensor_data in values(data.tensors)
        locations = tensor_data.locations
        @assert !isempty(locations)
        @assert allunique(locations)
    end

    # Get all the various configurations we want to capture for this run.
    remaining_configs = Set{Tuple{String, IOConfig}}()
    for op in ngraph_function
        keep(op) || continue

        inputs = [
            data.tensors[nGraph.get_name(t)].locations for t in nGraph.input_descriptors(op)
        ]
        outputs = [
           data.tensors[nGraph.get_name(t)].locations for t in nGraph.output_descriptors(op)
        ]

        op_name = nGraph.name(op)

        for input_config in Iterators.product(inputs...)
            for output_config in Iterators.product(outputs...)
                config = IOConfig(input_config, output_config)
                push!(remaining_configs, (op_name, config))
            end
        end
    end

    @info "Testing $(length(remaining_configs)) total configurations"

    loop_counter = 0

    # Keep track of the number of function runs
    run_count = Ref(0)

    while !isempty(remaining_configs)
        @info "Configurations Left: $(length(remaining_configs))"

        # Keep track of the nodes that are being tested so we don't overlap
        seen = Set{String}()

        simultaneous_configs = 0
        for (name, config) in remaining_configs
            # Abort if this node is already being tested
            in(name, seen) && continue

            # Abort if any neighbors of this node are under test
            inputs = nGraph.get_inputs(name_to_node[name])
            outputs = Iterators.flatten(nGraph.get_outputs(name_to_node[name]))
            neighbors = Iterators.flatten((inputs, outputs))
            any(in(seen), nGraph.name.(neighbors)) && continue

            # Set the config for the parent node and mark tha parent + all neighbors as seen
            # so the config is not overwritten
            _setup!(name_to_node[name], config)
            push!(seen, name)
            for neighbor in neighbors
                push!(seen, nGraph.name(neighbor))
            end

            # Update the number of configs we've used. If we're over the allowed number of
            # simultaneous configs, exit
            simultaneous_configs += 1
            simultaneous_configs >= max_simultaneous_configs && break
        end

        # Run the profiling
        # Run GC right before to clean up any left over buffers to ensure we have space
        # for the recompilation.
        GC.gc()
        fex = profile!(fex, args, data, name_to_node, run_count)

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

    return data
end

function profile!(fex, args, data, name_to_node, run_count::Ref{Int64}; runtime = Millisecond(1000))
    fex = nGraph.recompile(nGraph.Backend(), fex)
    time = now()
    while now() < time + runtime
        fex(args...)
        # Update run count
        run_count[] += 1
        tally!(data, fex, name_to_node, run_count[])
    end
    return fex
end

function tally!(data::ProfileData, fex, name_to_node, run_count::Int)
    f = fex.ex.ngraph_function

    function_name = nGraph.name(f)
    timings = JSON.parsefile("$function_name.timeline.json")["traceEvents"]

    # Slurp up all the results that haven't been seen yet.
    for node_data in data.nodes
        node_name = node_data.name
        keep(name_to_node[node_name]) || continue

        # Record the time for this config.
        config = getconfig(name_to_node[node_name])

        # Get the timing and record it
        index = findfirst(x -> x["name"] == node_name, timings)
        @assert index !== nothing
        time = timings[index]["dur"]

        timing_vec = get!(node_data.timings, config, Float64[])
        push!(timing_vec, time)

        run_number_vec = get!(node_data.run_numbers, config, Int64[])
        push!(run_number_vec, run_count)
    end

    return 
end

function getconfig(n::nGraph.Node)
    f = x -> nGraph.is_persistent(x) ? PMEM : DRAM
    input = map(f, nGraph.input_descriptors(n)) |> Tuple
    output = map(f, nGraph.output_descriptors(n)) |> Tuple
    return IOConfig(input, output)
end

reset!(fex) = map(_cleanup!, fex.ex.ngraph_function)

#####
##### Setup and cleanup code
#####

function _setup!(node::nGraph.Node, config::IOConfig)
    # Outputs
    for (i, location) in enumerate(config.outputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.output_descriptor(node, i))
        end
    end

    # Inputs
    for (i, location) in enumerate(config.inputs)
        if location == PMEM
            nGraph.make_persistent(nGraph.input_descriptor(node, i))
        end
    end
end

# Set everything back to volatile
function _cleanup!(node::nGraph.Node)
    nGraph.make_volatile.(nGraph.output_descriptors(node))
    nGraph.make_volatile.(nGraph.input_descriptors(node))
end

end # module
