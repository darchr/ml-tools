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
        keep(node.description) || continue

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
    names = collect(keys(F.profile_data.tensors))
    locations = Dict(name => F.profile_data.tensors[name].locations for name in names)

    @variable(F.model, tensors[name = names, location = locations[name]], Bin)

    @constraint(F.model,
        [name in names],
        sum(tensors[name, location] for location in locations[name]) == 1
    )

    return
end

# Node Configs
add_nodes!(::ILPGreedy, args...) = nothing
function add_nodes!(F::Frame{<:SimpleModel})
    for node_data in F.profile_data.nodes
        # We don't profile all ops, so perform a quick check to see if this is an op
        # the we have profile information for. If not, there's nothing to do as far as the
        # ILP model is concerned.
        keep(node_data.description) || continue

        configs = collect(keys(node_data.timings))

        # Create a variable for each config.
        vars = @variable(F.model, [config = configs], Bin)

        # Constrain each variable to be active if all of its inputs are active. We refer
        # to the tensors variables created earlier to generate these constrainrs.
        tensors = F.model[:tensors]

        @constraint(F.model,
            [config = configs],
            vars[config]
                - sum(tensors[n, config.inputs[i]] for (i,n) in enumerate(node_data.input_tensors))
                - sum(tensors[n, config.outputs[i]] for (i,n) in enumerate(node_data.output_tensors))
            >= 1 - length(config.inputs) - length(config.outputs)
        )

        # This constraint basically forces vars[config] to be zero if any of its inputs
        # are zero.
        #
        # It is not strictly necessary but are helpful to the solver.
        for config in configs
            config_iter = Iterators.flatten((config.inputs, config.outputs))
            name_iter = Iterators.flatten((node_data.input_tensors, node_data.output_tensors))
            for (loc, nm) in zip(config_iter, name_iter)
                @constraint(F.model, vars[config] <= tensors[nm, loc])
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
            coeff = round(Int64, minimum(node_data.timings[config]))
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
    tensors = F.model[:tensors]

    for (index, free_tensors) in enumerate(live_tensors(F.profile_data))
        live_free_tensors = filter(!in(F.profile_data.fixed_tensors), free_tensors)
        if !isempty(live_free_tensors)
            @constraint(F.model,
                sum(
                    round(Int, tensor_data[n].bytes / 1E6) * tensors[n, DRAM]
                    for n in live_free_tensors
                ) <= dram_limit
            )

            # Insert the objective for the greedy formulation
            if T == ILPGreedy
                objective_expr = F.model[:objective_expr]
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

function tensor_location(F::Frame{<:SimpleModel}, tensor_name)
    locations = F.profile_data.tensors[tensor_name].locations
    model_tensors = F.model[:tensors]

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

function getconfig(F::Frame{<:SimpleModel}, node_name)
    # Find this node name in the profile data.
    pd_node = F.profile_data.nodes[findfirst(x -> x.name == node_name, F.profile_data.nodes)]

    inputs = ntuple(
        x -> tensor_location(F, pd_node.input_tensors[x]),
        length(pd_node.input_tensors)
    )
    outputs = ntuple(
        x -> tensor_location(F, pd_node.output_tensors[x]),
        length(pd_node.output_tensors)
    )

    return IOConfig(inputs, outputs)
end

function configure!(fex::nGraph.FluxExecutable, F::Frame{<:SimpleModel}) 
    # Extract the function and set everything back to volatile to make sure we don't
    # have any carry-over from previous runs.
    fn = fex.ex.ngraph_function
    _cleanup!(fn)

    # Just look for the tensors that have been assigned to PMEM
    names = collect(keys(F.profile_data.tensors))
    tensors = F.profile_data.tensors

    # Make a dictionary so we can find the nGraph.Nodes by name.
    node_dict = Dict(nGraph.name(op) => op for op in fn)

    # Assign appropriate tensors to PMEM.
    for name in names
        # Check if this tensor can even live in DRAM
        if tensor_location(F, name) == PMEM
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
    return nGraph.recompile(fex), nothing
end
