function find_vertex(g, f)
    iter = filter_vertices(g, f) |> collect
    # Makesure we only have one match
    @assert length(iter) == 1
    return first(iter)
end
