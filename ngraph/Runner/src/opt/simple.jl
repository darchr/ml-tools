abstract type SimpleModel <: ModelType end

limit(x::SimpleModel) = x.dram_limit

# Minimize execution time with a DRAM Limit
struct Simple <: SimpleModel
    dram_limit::Int64
end

# Maximize DRAM usage with a DRAM Limit
struct ILPGreedy <: SimpleModel
    dram_limit::Int64
end

function predict(S::SimpleModel, model, profile_data) 
    # Base the expected runtime on the configs of all the kernels.
    runtime = zero(Float64)
    for node in profile_data.nodes
        node_name = node.name
        keep(node.description) || continue

        config = getconfig(S, model, profile_data, node_name)
        runtime += minimum(node.timings[config])
    end
    return runtime
end

# Shortcut for simple
predict(::Simple, model, profile_data) = objective_value(model)

#=
For each tensor, we generate a binary variable for each location the tensor can reside.
and constrain that one of these locations must be active.
=#

function create_model(modeltype::T, profile_data) where {T <: SimpleModel}
    # Start with an empty model that we will progressively build.
    model = Model(with_optimizer(Gurobi.Optimizer))

    # Create an empty expression that will be progressively generated to the final
    # objective.
    model[:objective_expr] = AffExpr()

    add_tensors!(modeltype, model, profile_data)
    add_nodes!(modeltype, model, profile_data)
    add_constraints!(modeltype, model, profile_data)

    # Add the objective expression we've built up.
    apply_objective!(modeltype, model)

    return model
end

apply_objective!(::SimpleModel, model) = @objective(model, Min, model[:objective_expr])
apply_objective!(::ILPGreedy, model) = @objective(model, Max, model[:objective_expr])

function add_tensors!(::SimpleModel, model, profile_data)
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

# Node Configs
add_nodes!(::ILPGreedy, args...) = nothing
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
            coeff = round(Int64, minimum(node_data.timings[config]))
            add_to_expression!(objective_expr, coeff, vars[config])
        end
    end
    return
end

# Constrain
function add_constraints!(modeltype::T, model, profile_data) where {T <: SimpleModel}
    # Unpack some variables
    dram_limit = limit(modeltype)
    tensor_data = profile_data.tensors
    tensors = model[:tensors]

    for (index, free_tensors) in enumerate(live_tensors(profile_data))
        live_free_tensors = filter(!in(profile_data.fixed_tensors), free_tensors)
        if !isempty(live_free_tensors)
            @constraint(model,
                sum(
                    round(Int, tensor_data[n].bytes / 1E6) * tensors[n, DRAM]
                    for n in live_free_tensors
                ) <= dram_limit
            )

            # Insert the objective for the greedy formulation
            if T == ILPGreedy
                objective_expr = model[:objective_expr]
                for tensor in live_free_tensors
                    add_to_expression!(
                        objective_expr,
                        round(Int, tensor_data[tensor].bytes / 1E6),
                        tensors[tensor, DRAM]
                    )
                end
            end
        end

    end

    return
end

#####
##### Configure nGraph
#####

function tensor_location(::SimpleModel, model::JuMP.Model, profile_data, tensor_name)
    locations = profile_data.tensors[tensor_name].locations
    model_tensors = model[:tensors]

    location_values = Tuple{TensorLocation,Float64}[]
    for location in locations
        val = value(model_tensors[tensor_name, location])
        push!(location_values, (location, val))

        if isapprox(val, one(val); atol=1e-3)
            return location
        end
    end

    # If none of the locations is one, that's definitely an error.
    @error """
    Tensor $tensor_name did not have an assigned location.
    Valid Locations: $locations
    Location Values: $location_values
    """
    error()
end

function getconfig(S::SimpleModel, model::JuMP.Model, profile_data, node_name)
    # Find this node name in the profile data.
    pd_node = profile_data.nodes[findfirst(x -> x.name == node_name, profile_data.nodes)]

    inputs = ntuple(
        x -> tensor_location(S, model, profile_data, pd_node.input_tensors[x]),
        length(pd_node.input_tensors)
    )
    outputs = ntuple(
        x -> tensor_location(S, model, profile_data, pd_node.output_tensors[x]),
        length(pd_node.output_tensors)
    )

    return IOConfig(inputs, outputs)
end

function configure!(S::SimpleModel, fex::nGraph.FluxExecutable, profile_data, model::JuMP.Model)
    # Extract the function and set everything back to volatile to make sure we don't
    # have any carry-over from previous runs.
    fn = fex.ex.ngraph_function
    backend = fex.ex.backend

    _cleanup!(fn)

    # Just look for the tensors that have been assigned to PMEM
    names = collect(keys(profile_data.tensors))
    tensors = profile_data.tensors

    # Make a dictionary so we can find the nGraph.Nodes by name.
    node_dict = Dict(nGraph.name(op) => op for op in fn)

    # Assign appropriate tensors to PMEM.
    for name in names
        # Check if this tensor can even live in DRAM
        if tensor_location(S, model, profile_data, name) == PMEM
            # Get the op that made this tensor
            op = node_dict[tensors[name].parent_name]

            # A quick sanity check on data integrity
            td = nGraph.output_descriptor(op, tensors[name].output_index)
            @assert nGraph.get_name(td) == name
            # Mark this tensor as persistent.
            nGraph.make_persistent(td)
        end
    end

    # Recompile the flux executable
    return nGraph.recompile(backend, fex)
end
