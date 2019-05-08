abstract type SimpleModel <: ModelType end

limit(x::SimpleModel) = x.dram_limit

# Minimize execution time with a DRAM Limit
struct Simple <: SimpleModel
    dram_limit::Int64
end
default_tolerance(::Simple) = 0.001

# Maximize DRAM usage with a DRAM Limit
#
# NOTE: When running, it might be baset to set MIP tolerance to 1% because the solver
# really struggles to get below about 0.6-0.7%
struct ILPGreedy <: SimpleModel
    dram_limit::Int64
end
default_tolerance(::ILPGreedy) = 0.01

function predict(F::Frame{<:SimpleModel}) 
    # Base the expected runtime on the configs of all the kernels.
    runtime = zero(Float64)
    for node in F.profile_data.nodes
        node_name = node.name
        hasprofile(node.description) || continue

        config = getconfig(F, node_name)
        runtime += minimum(node.timings[config])
    end
    return runtime
end

# Shortcut for simple
predict(F::Frame{Simple}) = objective_value(F.model)

#=
For each tensor, we generate a binary variable for each location the tensor can reside.
and constrain that one of these locations must be active.
=#

function create_model(
        modeltype::T, 
        profile_data; 
        tolerance = default_tolerance(modeltype)
    ) where {T <: SimpleModel}

    # Start with an empty model that we will progressively build.
    #
    # Slightly loosen the gap to .1% because at that point, who cares anyways?
    model = Model(with_optimizer(Gurobi.Optimizer; TimeLimit = 120, MIPGap = tolerance))
    frame = Frame(modeltype, model, profile_data)

    # Create an empty expression that will be progressively generated to the final
    # objective.
    model[:objective_expr] = AffExpr()

    add_tensors!(frame)
    add_nodes!(frame)
    add_constraints!(frame)

    # Add the objective expression we've built up.
    apply_objective!(frame)

    return frame
end

apply_objective!(F::Frame{<:SimpleModel}) = 
    @objective(F.model, Min, F.model[:objective_expr])

apply_objective!(F::Frame{ILPGreedy}) = 
    @objective(F.model, Max, F.model[:objective_expr])

function add_tensors!(F::Frame{<:SimpleModel})
    # Get all the tensors in the graph
    data = F.profile_data

    @variable(F.model, 
        var_tensors[
            tensor = tensors(data), 
            location = locations(data, tensor)
        ], Bin
    )

    @constraint(F.model,
        [tensor in tensors(data)],
        sum(var_tensors[tensor, location] for location in locations(data, tensor)) == 1
    )

    return
end

# Node Configs
add_nodes!(::ILPGreedy, args...) = nothing
function add_nodes!(F::Frame{<:SimpleModel})
    data = F.profile_data
    for node in nodes(data)
        # We don't profile all ops, so perform a quick check to see if this is an op
        # the we have profile information for. If not, there's nothing to do as far as the
        # ILP model is concerned.
        hasprofile(node) || continue

        configs = collect(keys(node.timings))

        # Create a variable for each config.
        vars = @variable(F.model, [config = configs], Bin)

        # Constrain each variable to be active if all of its inputs are active. We refer
        # to the tensors variables created earlier to generate these constrainrs.
        var_tensors = F.model[:var_tensors]

        @constraint(F.model,
            [config = configs],
            vars[config] - 
                sum(var_tensors[t, c] for (t,c) in zip(inputs(node), config.inputs)) -
                sum(var_tensors[t, c] for (t,c) in zip(outputs(node), config.outputs))
            >= 1 - length(config.inputs) - length(config.outputs)
        )

        # This constraint basically forces vars[config] to be zero if any of its inputs
        # are zero.
        #
        # It is not strictly necessary but are helpful to the solver.
        for config in configs
            config_iter = Iterators.flatten((config.inputs, config.outputs))
            name_iter = Iterators.flatten((inputs(node), outputs(node)))
            for (loc, nm) in zip(config_iter, name_iter)
                @constraint(F.model, vars[config] <= var_tensors[nm, loc])
            end
        end

        # One of these configs must be active
        #
        # While this constraint pops out from the objective, it really helps the solver
        # so include it.
        @constraint(F.model, sum(vars[config] for config in configs) == 1)

        # Mutate the "objective_expr" with these timings
        objective_expr = F.model[:objective_expr]
        for config in configs
            # For now, just use the Mean
            coeff = round(Int64, minimum(node.timings[config]))
            add_to_expression!(objective_expr, coeff, vars[config])
        end
    end
    return
end

# Constrain
function add_constraints!(F::Frame{T}) where {T <: SimpleModel}
    # Unpack some variables
    dram_limit = limit(F.modeltype)
    tensor_data = F.profile_data.tensors
    var_tensors = F.model[:var_tensors]

    for (index, live_tensors) in enumerate(live_tensors(F.profile_data))
        node = nodes(F.profile_data, index)
        hasprofile(node) || continue

        if !isempty(live_tensors)
            @constraint(F.model,
                sum(
                    round(Int, sizeof(n) / 1E6) * var_tensors[n, DRAM] for n in live_tensors
                ) <= dram_limit
            )

            # Insert the objective for the greedy formulation
           #  if T == ILPGreedy
           #      objective_expr = F.model[:objective_expr]
           #      for tensor in live_free_tensors
           #          add_to_expression!(
           #              objective_expr,
           #              round(Int, tensor_data[tensor].bytes / 1E6),
           #              var_tensors[tensor, DRAM]
           #          )
           #      end
           #  end
        end 
    end

    return
end

#####
##### Configure nGraph
#####

function tensor_location(F::Frame{<:SimpleModel}, tensor::TensorWrapper)
    var_tensors = F.model[:var_tensors]

    location_values = Tuple{TensorLocation,Float64}[]
    for location in locations(F.profile_data, tensor)
        val = value(var_tensors[tensor, location])
        push!(location_values, (location, val))

        if approx_one(val)
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

function getconfig(F::Frame{<:SimpleModel}, node::NodeWrapper)
    _inputs = ntuple(x -> tensor_location(F, inputs(node)[x]), length(inputs(node)))
    _outputs = ntuple(x -> tensor_location(F, outputs(node)[x]), length(outputs(node)))

    return IOConfig(_inputs, _outputs)
end

function configure!(fex::nGraph.FluxExecutable, F::Frame{<:SimpleModel}) 
    # Extract the function and set everything back to volatile to make sure we don't
    # have any carry-over from previous runs.
    fn = fex.ex.ngraph_function
    _cleanup!(fn)

    # Just look for the tensors that have been assigned to PMEM
    data = F.profile_data 

    # Assign appropriate tensors to PMEM.
    for tensor in tensors(data)
        # Check if this tensor can even live in DRAM
        if tensor_location(F, tensor) == PMEM
            make_persistent(fex, data, tensor)
        end
    end

    # Recompile the flux executable
    return nGraph.recompile(fex), nothing
end
