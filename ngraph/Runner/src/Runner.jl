module Runner

using nGraph, Flux, JSON
using Dates, Statistics
using RecipesBase
using LightGraphs, MetaGraphs
using IterTools

@enum TensorLocation::UInt8 DRAM PMEM

include("setup.jl")
include("finder.jl")
include("opt/opt.jl")
include("models/simple.jl")

keep(op_description::String) = !in(op_description, ("Parameter", "Constant", "Result"))
keep(op::nGraph.Node) = keep(nGraph.description(op))

# NOTE: Since we're playing around with ILP formulations, we do NOT want to have to 
# rerun the memory profiling step every time we restart Julia.
#
# Thus, all data structures that end up in the final `ProfileData` MUST NOT contain
# any ngraph c++ pointers, otherwise serialization and deserialization will not work.
#
# Note that this would be even harder if were were just using straight C++ because
# C++ does not have data structure serialization natively. We could have used something
# like Goost::serialization, but I think that would be WAY more trouble than its worth.


"""
Location information for the input and output tensors of a node.
"""
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

"""
Information about tensors in an ngraph function.

Fields
------
* `name` - The unique name for the tensor. NOTE: nGraph makes the guarantee that
    tensor names are unique, but I have not independently verified that.

* `bytes` - The allocation size of the tensor in bytes

* `locations::Vector{TensorLocation}` - The set of valid memory pool that this tensor
    can be assigned to.
"""
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

"""
Meta data about nGraph nodes

Fields
------

* `name::String` - The unique name of this node.

* `description::String` - Description string for this node. All nodes that perform the
    exact same operation will have the exact same description.

* `input_tensors::Vector{String}` - **Ordered** names of input tensors.

* `output_tensors::Vector{String}` - **Ordered** names of output tensors.

* `timings::Dict{IOConfig, Vector{Float64}}` - Measurement execution times for this
    node for a given `IOConfig`.

* `run_numbers::Dict{IOConfig, Vector{Int64}}` - To support future analysis, the run
    numbers are also recorded and have a similar structure to the timing numbers.

    That is, `run_numbers[config][i]` will be the run number for `timings[config][i]`.
"""
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


"""
NOTE: All children of this type should be pure Julia objects and contain no references
or pointers to ngraph C++ objects - otherwise it won't serialize correctly.

Fields
------

* `tensors::Dict{String, TensorData}` - All tensors that occur in a ngraph function.
    Keyed by name for easy lookup.

* `nodes::Vector{NodeData}` - All of the nodes in the ngraph function, **ordered** by
    their execution time.

* `newlist::Vector{Vector{String}}` - Records the tensors that are newly created
    at op `i`, indexed by `i`. The following generally holds: 
    `nodes.output_tensors[i] == newlist[i]`

* `freelist::Vector{Vector{String}}` - Records the tensors that are freed at op `i`,
    indexed by `i`.
"""
struct ProfileData
    tensors::Dict{String, TensorData}

    # Stored in program order.
    nodes::Vector{NodeData}

    # Liveness Analysis
    newlist::Vector{Vector{String}}
    freelist::Vector{Vector{String}}
    fixed_tensors::Set{String}
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
        liveness.free_list,
        liveness.fixed_tensors
    )
end

function liveness_analysis(nodes::Vector{NodeData})
    # Get the tensors that we can't move yet
    fixed_tensors = find_fixed_tensors(nodes)

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

    return (new_list = new_list, free_list = free_list, fixed_tensors = fixed_tensors)
end

function find_fixed_tensors(nodes::Vector{NodeData})
    tensors = Set{String}()
    for node in nodes
        if in(node.description, ("Parameter", "Constant", "Result"))
            for tensor in node.output_tensors
                @assert !in(tensor, tensors)
                push!(tensors, tensor)
            end
        end
    end
    return tensors
end

struct LiveTensorIterator
    data::ProfileData
    live_tensors::Set{String}
end

live_tensors(data::ProfileData) = LiveTensorIterator(data, Set{String}())

Base.length(L::LiveTensorIterator) = length(L.data.newlist)
function Base.iterate(L::LiveTensorIterator, s = 1)
    s > length(L) && return nothing

    # Free tensors from the previous iteration
    if s > 1
        for tensor in L.data.freelist[s-1]
            delete!(L.live_tensors, tensor)
        end
    end

    # Add new tensors for this iteration
    for tensor in L.data.newlist[s]
        push!(L.live_tensors, tensor)
    end

    return L.live_tensors, s+1
end


"""
    allocation_bounds(data::ProfileData)

Return upper and lower bounds on the amount of DRAM required for input, output, 
constant, and intermediate tensors.

Upper bound is determined by the maximum tensors concurrently live.

Lower bound is determined by the total size of input, output, and constant tensors.
"""
function allocation_bounds(data::ProfileData)
    # Lower bound should always be zero since we're ignoring fixed tensors
    lower_bound = 0

    # Compute Upper Bound
    upper_bound = 0
    for tensors in live_tensors(data)
        free_tensors = filter(!in(data.fixed_tensors), tensors)
        if !isempty(free_tensors)
            upper_bound = max(upper_bound, sum(data.tensors[n].bytes for n in free_tensors))
        end
    end

    return (upper_bound = upper_bound, lower_bound = lower_bound)
end

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
    setup_pmem()
    local x
    try
        x = _memory_profile(fex, args; kw...)
    finally
        delete!(ENV, "NGRAPH_PASS_HACK")
    end
    return x
end

function _memory_profile(fex::nGraph.FluxExecutable, args; max_simultaneous_configs = typemax(Int64))

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
            if in(nGraph.description(op), ("Constant", "Parameter", "Result"))
                push!(data.tensors[tensor_name].locations, DRAM)

            # Generic tensors can live in either DRAM or PMEM
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
    for descriptor in nGraph.output_descriptors(node)
        nGraph.make_volatile(descriptor)
        nGraph.reset_offset(descriptor)
    end
    for descriptor in nGraph.input_descriptors(node)
        nGraph.make_volatile(descriptor)
        nGraph.reset_offset(descriptor)
    end
end

include("visualize.jl")

end # module
