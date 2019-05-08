function _cost(t::TensorWrapper, users::Dict)
    # Get the nodes using this tensor
    u = users[t]

    # For each user, get the DRAM/PMEM config of the tensor
    configs = [Runner.getconfig(unwrap(n)) for n in u]

    # Get the base cost
    # Some nodes may not have timing information, so just return 0.0 for those.
    #
    # Do the ternary operator instead of `get` so we know if somewhere the profiling of
    # that node goes wrong.
    times = [Runner.hasprofile(u) ? u.timings[c] : [0.0] for (u,c) in zip(u, configs)] 
    cost = sum(minimum.(times))
    return cost
end

function marginal_costs(fex::nGraph.FluxExecutable, data::Runner.ProfileData)
    marginals = Dict{TensorWrapper, Float64}()

    # Speed up tensors to users
    users = Dict{TensorWrapper, Set{Runner.NodeWrapper}}()
    for node in nodes(data)
        for tensor in Iterators.flatten((outputs(node), inputs(node)))
            s = get!(users, tensor, Set{Runner.NodeWrapper}())
            push!(s, node)
        end
    end

    for tensor in tensors(data)
        in(Runner.PMEM, Runner.locations(data, tensor)) || continue

        # Get the base cost for the tensor
        base_cost = _cost(tensor, users)

        # Swap the state of the tensor
        in_pmem = Runner.is_persistent(tensor)
        if in_pmem
            Runner.make_volatile(fex, data, tensor)
        else
            Runner.make_persistent(fex, data, tensor)
        end

        new_cost = _cost(tensor, users)

        # Swap back
        if in_pmem
            Runner.make_persistent(fex, data, tensor)
        else
            Runner.make_volatile(fex, data, tensor)
        end

        cost = new_cost - base_cost
        
        marginals[tensor] = cost
    end
    return MarginalPlot(marginals)
end

struct MarginalPlot
    data::Dict{TensorWrapper, Float64}
end

@recipe function f(marginals::MarginalPlot)

    seriestype := :scatter
    legend := :none

    x = Float64[]
    y = Float64[]
    colors = Symbol[]

    @series begin
        for (tensor, cost) in marginals.data
            push!(x, cost)
            push!(y, sizeof(tensor))
            push!(colors, Runner.is_persistent(tensor) ? :red : :blue)
        end

        c := colors
        x, y
    end

end
