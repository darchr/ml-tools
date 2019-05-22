struct ReusePlot end
@recipe function f(::ReusePlot, p::ProfileData)
    # Operate at a 1MiB granularity to avoid taking forever.
    pagesize = 1E6
    buckets = map(Runner.nodes(p)) do node
        pages = Set{Int}()

        for tensor in Iterators.flatten((Runner.inputs(node), Runner.outputs(node)))
            offset = floor(Int, nGraph.get_pool_offset(Runner.unwrap(tensor)) / pagesize)
            sz = sizeof(tensor)
            for i in offset:offset + ceil(Int, sz / pagesize)
                push!(pages, i)
            end
        end
        return pages
    end

    r = Runner.reuse(buckets)

    y = Runner.cdf(r.upper)
    x = collect(1:length(y))

    seriestype := :line
    xlabel := "Reuse Distance (MiB)"
    ylabel := "CDF"
    legend := :none

    @series begin
        x, y
    end
end
