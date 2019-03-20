module Runner

using nGraph, Flux, JSON
using Dates

include("models/simple.jl")

#####
##### PMEM initialization
#####

function setup_pmem(file = "/mnt/public/file.pmem", size = 2^36)
    ispath(file) && rm(file)

    manager = nGraph.Lib.getinstance()
    nGraph.Lib.create_pool(manager, file, convert(UInt, size))
    return nothing
end

#####
##### Setup Affinities
#####

# Documentation on KMP_HW_SUBSET:
#
# Specifies the number of sockets, cores per socket, and the number of threads per core, to 
# use with an OpenMP* application, as an alternative to writing explicit affinity settings 
# or a process affinity mask. You can also specify an offset value to set which resources 
# to use.
#
# An extended syntax is available when KMP_TOPOLOGY_METHOD=hwloc. Depending on what 
# resources are detected, you may be able to specify additional resources, such as NUMA 
# nodes and groups of hardware resources that share certain cache levels. For example, 
# tiles are sets of cores that share an L2 cache on some processors in the Intel® Xeon Phi™ 
# family.
#
# Basic syntax:
#
# socketsS[@offset],coresC[@offset],threadsT
#
# S, C and T are not case-sensitive.
#
# - sockets: The number of sockets to use.
# - cores: The number of cores to use per socket.
# - threads: The number of threads to use per core.
# - offset: (Optional) The number of sockets or cores to skip.
#
# Extended syntax when KMP_TOPOLOGY_METHOD=hwloc:
# 
# socketsS[@offset],numasN[@offset],tilesL2[@offset],coresC[@offset],threadsT
# 
# S, N, L2, C and T are not case-sensitive. Some designators are aliases on some machines. 
# Specifying duplicate or multiple alias designators for the same resource type is not 
# allowed.
# 
# - sockets: The number of sockets to use.
# - numas: If detectable, the number of NUMA nodes to use per socket,where available.
# - tiles: If detectable, the number of tiles to use per NUMA node, where available, otherwise per socket.
# - cores: The number of cores to use per socket, where available, otherwise per NUMA node, or per socket.
# - threads: The number of threads to use per core.
# - offset: (Optional) The number of sockets or cores to skip.
#
# NOTE
# If you don't specify one or more types of resource, sockets, cores or threads, all 
# available resources of that type are used.
#
# NOTE
# If a particular type of resource is specified, but detection of that resource is not 
# supported by the chosen topology detection method, the setting of KMP_HW_SUBSET is ignored.
#
# NOTE
# This variable does not work if the OpenMP* affinity is set to disabled.
# Default: If omitted, the default value is to use all the available hardware resources.
# 
# Examples:
# 
# 2s,4c,2t: Use the first 2 sockets (s0 and s1), the first 4 cores on each socket (c0 - c3), 
# and 2 threads per core.
# 
# 2s@2,4c@8,2t: Skip the first 2 sockets (s0 and s1) and use 2 sockets (s2-s3), skip the 
# first 8 cores (c0-c7) and use 4 cores on each socket (c8-c11), and use 2 threads per core.
# 
# 5C@1,3T: Use all available sockets, skip the first core and use 5 cores, and use 3 threads 
# per core.
# 
# 2T: Use all cores on all sockets, 2 threads per core.
# 
# 4C@12: Use 4 cores with offset 12, all available threads per core.
function setup_affinities()
    ENV["KMP_AFFINITY"] = "compact,granularity=fine"

    # Use the first 24 cores - 2 threads for each core
    # Send to numa-node 1 for a hopefully more quiet system
    ENV["KMP_HW_SUBSET"] = "1s@1,1t"

    # 2 Threads for each cor
    ENV["OMP_NUM_THREADS"] = 24
end

teardown_affinities() = delete!.(Ref(ENV), ("KMP_AFFINITY", "KMP_HW_SUBSET", "OMP_NUM_THREADS"))

function setup_profiling()
    nGraph.enable_codegen()
    nGraph.enable_timing()
end

_skip(op) = in(nGraph.description(op), ("Parameter", "Constant", "Result"))
keep(op) = !_skip(op)

@enum TensorLocation::UInt8 DRAM PMEM

struct NodeConfig{N, M}
    inputs::NTuple{N, TensorLocation}
    outputs::NTuple{M, TensorLocation}
end
function Base.show(io::IO, config::NodeConfig{N,M}) where {N,M}
    f = x -> (x == DRAM) ? "DRAM" : "PMEM" 
    print(io, "NodeConfig{N,M}: ")
    print(io, "(", join(f.(config.inputs), ", "), ") -- ")
    print(io, "(", join(f.(config.outputs), ", "), ")")
end

struct TimeData
    time::Float64
    run_number::Int64
end
gettime(T::TimeData) = T.time
getnumber(T::TimeData) = T.run_number

struct ProfileData
    name::String
    description::String
    input_sizes::Vector{Int64}
    output_sizes::Vector{Int64}
    timings::Dict{NodeConfig,Vector{TimeData}}
end

ProfileData(node::nGraph.Node) = ProfileData(
    nGraph.name(node),
    nGraph.description(node),
    sizeof.(nGraph.input_descriptors(node)),
    sizeof.(nGraph.output_descriptors(node)),
    Dict{NodeConfig,Vector{Float64}}(),
)


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
    results = Dict(nGraph.name(op) => ProfileData(op)
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
        fex = profile!(fex, args, results, name_to_node, run_count)
        #tally!(results, fex, name_to_node)

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

function profile!(fex, args, results, name_to_node, run_count::Ref{Int64}; runtime = Millisecond(5000))
    fex = nGraph.recompile(nGraph.Backend(), fex)
    time = now()
    while now() < time + runtime
        fex(args...)
        # Update run count
        run_count[] += 1
        tally!(results, fex, name_to_node, run_count[])
    end
    return fex
end

function tally!(results::Dict{String, ProfileData}, fex, name_to_node, run_count::Int)
    f = fex.ex.ngraph_function

    function_name = nGraph.name(f)
    timings = JSON.parsefile("$function_name.timeline.json")["traceEvents"]

    # Slurp up all the results that haven't been seen yet.
    for (node_name, profile_data) in results
        # Record the time for this config.
        config = getconfig(name_to_node[node_name])

        # Get the timing and record it
        index = findfirst(x -> x["name"] == node_name, timings)
        @assert index !== nothing
        time = timings[index]["dur"]

        timing_vec = get!(profile_data.timings, config, TimeData[])
        push!(timing_vec, TimeData(time, run_count))
    end
end

function getconfig(n::nGraph.Node)
    f = x -> nGraph.is_persistent(x) ? PMEM : DRAM
    input = map(f, nGraph.input_descriptors(n)) |> Tuple
    output = map(f, nGraph.output_descriptors(n)) |> Tuple
    return NodeConfig(input, output)
end

reset!(fex) = map(_cleanup!, fex.ex.ngraph_function)

#####
##### Setup and cleanup code
#####

function _setup!(node::nGraph.Node, config::NodeConfig)
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
