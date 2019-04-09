struct Simple <: ModelType
    dram_limit::Int64
end

predict(::Simple, model) = objective_value(model)

#=
For each tensor, we generate a binary variable for each location the tensor can reside.
and constrain that one of these locations must be active.
=#

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
            coeff = round(Int64, minimum(node_data.timings[config]))
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

#####
##### Configure nGraph
#####

function configure!(::Simple, fex::nGraph.FluxExecutable, profile_data, model::JuMP.Model)
    # Extract the function and set everything back to volatile to make sure we don't
    # have any carry-over from previous runs.
    fn = fex.ex.ngraph_function
    backend = fex.ex.backend

    _cleanup!(fn)

    # Just look for the tensors that have been assigned to PMEM
    names = collect(keys(profile_data.tensors))     
    locations = Dict(name => profile_data.tensors[name].locations for name in names)

    tensors = model[:tensors]

    # Assign appropriate tensors to PMEM.
    for name in names
        # Check if this tensor can even live in DRAM
        if in(PMEM, locations[name]) && isapprox(value(tensors[name, PMEM]), 1)

            # Find the op that created this tensor.
            # NOTE: We're assuming that the names and order of the nodes has not
            # changed. Since the `Simple` model does not add or remove nodes, this
            # assumption should hold.
            found = false 
            for (fn_node, pd_node) in zip(fn, profile_data.nodes)
                ind = findfirst(isequal(name), pd_node.output_tensors)
                if ind !== nothing
                    nGraph.make_persistent(nGraph.output_descriptor(fn_node, ind))
                    found = true
                    break
                end
            end
            # Raise an error if we didn't find this tensor.
            @assert found
        end
    end

    # Recompile the flux executable
    return nGraph.recompile(backend, fex)
end
