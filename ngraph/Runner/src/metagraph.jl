# Why do these not exist in LightGraphs.jl??
inedges(g, v) = (edgetype(g)(u, v) for u in inneighbors(g, v))
outedges(g, v) = (edgetype(g)(v, u) for u in outneighbors(g, v))

struct MetaGraph{T,E,V} <: AbstractGraph{T}
    graph::SimpleDiGraph{T}
    edge_meta::E
    vertex_meta::V

    function MetaGraph(graph::SimpleDiGraph{T}, ::Type{E}, ::Type{V}) where {T,V,E}
        edge_meta = Dict{edgetype(graph),E}()
        vertex_meta = Dict{eltype(graph),V}()
        return new{T,typeof(edge_meta),typeof(vertex_meta)}(graph, edge_meta, vertex_meta)
    end
end


const LIGHTGRAPHS_INTERFACE = (
    :(Base.reverse),
    :(LightGraphs.dst),
    :(LightGraphs.edges),
    :(LightGraphs.edgetype),
    :(LightGraphs.has_edge),
    :(LightGraphs.has_vertex),
    :(LightGraphs.inneighbors),
    :(LightGraphs.is_directed),
    :(LightGraphs.ne),
    :(LightGraphs.nv),
    :(LightGraphs.outneighbors),
    :(LightGraphs.src),
    :(LightGraphs.vertices),
)
for f in LIGHTGRAPHS_INTERFACE
    eval(:($f(M::MetaGraph, x...) = $f(M.graph, x...)))
end

LightGraphs.add_edge!(M::MetaGraph, src, dst) = add_edge!(M.graph, src, dst)
function LightGraphs.add_edge!(M::MetaGraph, src, dst, metadata) 
    success = add_edge!(M.graph, src, dst)
    if success
        M.edge_meta[edgetype(M.graph)(src, dst)] = metadata
    end
    return success
end

LightGraphs.add_vertex!(M::MetaGraph) = add_vertex!(M.graph)
function LightGraphs.add_vertex!(M::MetaGraph, metadata)
    success = add_vertex!(M.graph)
    if success
        M.vertex_meta[nv(M)] = metadata
    end
    return success
end

_meta(M::MetaGraph, v::Integer) = M.vertex_meta[v]
_meta(M::MetaGraph, e) = M.edge_meta[e]

function rem_edge!(M::MetaGraph, e)
    success = rem_edge!(M.graph, e)
    if success
        delete!(M.edge_meta, e)
    end
    return success
end

