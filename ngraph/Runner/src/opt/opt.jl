# Sub project for taking a set of profiled data and building a JuMP model forming some
# optimization problem over that data.
#
# The main initial goal is to
# - Minimize the sum of kernel execution times
# - By assigning the locations of live intermediate tensors to either DRAM or PMEM
# - With a fixed memory budget of live tensors in DRAM
#
# However, we would like the framework to be flexible enough to allow swapping in of
# different:
#
# - Models for kernel execution times
# - High level problem descriptions
# - Retain the ability to insert "move" nodes and perform more complicated passes.
#
# #####
# ##### Initial Setup
# #####
#
# For just the initial formulation, we need the following pipeline:
#
# - Base data structure will be a vector of nGraph ops in `ordered_ops` structure,
#   which is the order that they are executed by the nGraph runtime.
#
# - Get a list of all intermediate tensors and sizes.
#   Each tensor can either live in DRAM or PMEM, so we need to generate JuMP variables
#   accordingly.
#
# - Do a liveness analysis to determine where tensors begin and when they go out of
#   scope.
#
# - Iterate through each op in the nGraph ops. For each op, generate
#
#   1. A capacity constraint on the number of live tensors in DRAM.
#   2. Generate a `gadget` to encode the running time of the kernel given the locations
#      of its inputs and outputs.
#   3. Add the results of this gadget to the global objective function, which will be
#      to minimize the sum of active running times.
#
# To accomplish this, we need to pass around a JuMP `Model` which we may progressively
# add variables and constraints to.
#
# To sequentially build the objective function, we can have a JuMP `expression`
# (http://www.juliaopt.org/JuMP.jl/v0.19.0/expressions/) which we update with the
# `add_to_expression!` function at each node in the graph.
using JuMP, Gurobi

# For dispatch purposes
abstract type ModelType end

struct Simple <: ModelType
    dram_limit::Int64
end

include("sync.jl")

function create_model(modeltype::T, profile_data) where {T <: ModelType}
    # Start with an empty model that we will progressively build.
    model = Model(with_optimizer(Gurobi.Optimizer))

    # Create an empty expression that will be progressively generated to the final
    # objective.
    model[:objective_expr] = AffExpr()

    add_tensors!(modeltype, model, profile_data)
    add_nodes!(modeltype, model, profile_data)
    add_constraints!(modeltype, model, profile_data)

    # Add the objective expression we've built up.
    @objective(model, Min, model[:objective_expr])

    return model
end

#=
For each tensor, we generate a binary variable for each location the tensor can reside.
and constrain that one of these locations must be active.
=#
function add_tensors!(::Simple, model, profile_data)
    # Get all the tensors in the graph
    names = collect(keys(profile_data.tensors))
    locations = Dict(name => profile_data.tensors[name].locations for name in names)

    @variable(model, tensors[name = names, location = locations[name]], Bin)

    @constraint(model,
        [name in names],
        sum(tensors[name, location] for location in locations[name]) == 1
    )

    return
end

function add_nodes!(::ModelType, model, profile_data)
    for node_data in profile_data.nodes
        # We don't profile all ops, so perform a quick check to see if this is an op
        # the we have profile information for. If not, there's nothing to do as far as the
        # ILP model is concerned.
        keep(node_data.description) || continue

        configs = collect(keys(node_data.timings))

        # Create a variable for each config.
        vars = @variable(model, [config = configs], Bin)

        # Constrain each variable to be active if all of its inputs are active. We refer
        # to the tensors variables created earlier to generate these constraings.
        tensors = model[:tensors]

        @constraint(model, 
            [config = configs], 
            vars[config] 
                - sum(tensors[n, config.inputs[i]] for (i,n) in enumerate(node_data.input_tensors))
                - sum(tensors[n, config.outputs[i]] for (i,n) in enumerate(node_data.output_tensors))
            >= 1 - length(config.inputs) - length(config.outputs)
        )

        # Mutate the "objective_expr" with these timings
        objective_expr = model[:objective_expr] 
        for config in configs
            # For now, just use the Mean
            coeff = round(Int64, min(node_data.timings[config]))
            add_to_expression!(objective_expr, coeff, vars[config])
        end
    end
    return
end

function add_constraints!(modeltype::Simple, model, profile_data)
    # Unpack some variables
    dram_limit = modeltype.dram_limit 
    tensor_data = profile_data.tensors
    fixed_tensors = profile_data.fixed_tensors
    tensors = model[:tensors]

    live_tensors = Set{String}()
    for (index, node_data) in enumerate(profile_data.nodes)
        # Another sanity check to make sure all the expected tensors are live
        @assert all(in(live_tensors), node_data.input_tensors)

        # Add Tensors
        for tensor_name in profile_data.newlist[index]
            # Sanity Check
            @assert !in(tensor_name, live_tensors)
            push!(live_tensors, tensor_name)
        end

        live_free_tensors = filter(!in(fixed_tensors), live_tensors)
        if !isempty(live_free_tensors)
            @constraint(model, 
                sum(
                    tensor_data[n].bytes * tensors[n, DRAM] 
                    for n in live_free_tensors 
                ) <= dram_limit
            )
        end

        # Free Tensors
        for tensor_name in profile_data.freelist[index]
            delete!(live_tensors, tensor_name)
        end
    end

    return
end
