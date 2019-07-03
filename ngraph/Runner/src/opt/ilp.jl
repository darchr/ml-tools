# Model with synchronous "move" nodes
#
# The formulation here is similar to the "Simple" formulation, but now data is allowed
# to move from DRAM to PMEM using synchronous move nodes. Using a move node adds
# execution time based on the relative read and write bandwidths.
#
# This is realized by generating a tensor location set for each op the tensor is live.
#
# We then create a variable that is "active" when a tensor changes location from DRAM
# to PMEM. These variables will add time to the objective function
struct TensorMeta
    graph::MetaGraph

    # Nodes using this tensor
    users::Vector{NodeDescriptor}

    # Look-up a node wrapper, get the node that serves as a reference for this
    reference_map::Dict{NodeDescriptor, NodeDescriptor}
end

get_reference(S::TensorMeta, node::NodeDescriptor) = S.reference_map[node]
graph(S::TensorMeta) = S.graph
users(S::TensorMeta) = S.users

#####
##### Model Types
#####

# Singleton types for dispatching to different formulations
abstract type ILPFormulationType end
struct IsFixed <: ILPFormulationType end
struct IsSynchronous <: ILPFormulationType end
struct IsAsynchronous <: ILPFormulationType end

mutable struct ILPHolder{T <: ILPFormulationType}
    dram_limits::Vector{Int}
    descriptors::Dict{TensorDescriptor, TensorMeta}
    async_move_vars::Dict{NodeDescriptor, Vector{JuMP.VariableRef}}
    node_to_limit_index::Dict{NodeDescriptor, Int}

    # Bandwidths
    read_bandwidth::Int64
    write_bandwidth::Int64
    read_bandwidth_async::Int64
    write_bandwidth_async::Int64
end

# Add factory methods
exceeds_limit(fex, I::ILPHolder) =
    (nGraph.get_temporary_pool_size(fex.ex.ngraph_function) / 1E6) > maxlimit(I)

# The general idea is that heap fragmentation causes the actual allocated amount to 
# exceed the limit.
#
# To deal with this, we take the FIRST instance where the memory limit is exceeded due
# to fragmentation and reduce the DRAM limit for the node just BEFORE that instance.
#
# This should cause the ngraph allocator to free up some space so we don't go over the 
# limit.
function update(I::T, 
            fex::nGraph.FluxExecutable, 
            data::ProfileData,
       ) where {T <: ILPHolder}

    dram_limits = I.dram_limits
    ml = maxlimit(I)

    # Go through all of the live tensors - find the first that exceeds the limit
    offending_tensors = TensorDescriptor[]
    for live in live_tensors(data)  
        # Find the DRAM tensors
        dram_tensors = filter(!nGraph.is_persistent, live)
        isempty(dram_tensors) && continue

        # Find the first out of bounds tensor
        for tensor in dram_tensors
            sz = (nGraph.get_pool_offset(tensor) + sizeof(tensor)) / 1E6
            if sz > ml
                push!(offending_tensors, tensor)
            end
        end
    end

    # Update the dram limits on all the producers
    indices = Int[]
    for tensor in offending_tensors 
        for node in _users(tensor, data)
            (ismove(node) || !hasprofile(node)) && continue
            push!(indices, I.node_to_limit_index[node])

            # j = data.node_to_index[node]
            # for (o, s) in offsetsizes[j]
            #     println("    $o  ->  $s")
            # end
        end
    end

    #@show unique(indices)
    for idx in unique(indices)
        dram_limits[idx] = round(Int, 0.95 * dram_limits[idx])
    end

    # Return a new ILHolder
    return T(dram_limits,
        Dict{TensorDescriptor, TensorMeta}(),
        Dict{NodeDescriptor, Vector{JuMP.VariableRef}}(),
        Dict{NodeDescriptor, Int}(),
        rb(I),
        wb(I),
        rba(I),
        wba(I),
    )
end

# Accessor methods
rb(I::ILPHolder) = I.read_bandwidth
wb(I::ILPHolder) = I.write_bandwidth
rba(I::ILPHolder) = I.read_bandwidth_async
wba(I::ILPHolder) = I.write_bandwidth_async

static(dram_limits) = ILPHolder{IsFixed}(
    dram_limits,
    Dict{TensorDescriptor, TensorMeta}(),
    Dict{NodeDescriptor, Vector{JuMP.VariableRef}}(),
    Dict{NodeDescriptor, Int}(),
    1,1,1,1,
)

synchronous(dram_limits, a, b) = ILPHolder{IsSynchronous}(
    dram_limits,
    Dict{TensorDescriptor, TensorMeta}(),
    Dict{NodeDescriptor, Vector{JuMP.VariableRef}}(),
    Dict{NodeDescriptor, Int}(),
    a,b,1,1,
)

asynchronous(dram_limits,a,b,c,d) = ILPHolder{IsAsynchronous}(
    dram_limits,
    Dict{TensorDescriptor, TensorMeta}(),
    Dict{NodeDescriptor, Vector{JuMP.VariableRef}}(),
    Dict{NodeDescriptor, Int}(),
    a,b,c,d,
)

# Common Methods

# Length check because ngraph compilation is not 100 % consistent and can sometimes have
# a few more nodes than it began with ...
limit(F::Frame, args...) = limit(F.modeltype, args...)
limit(S::ILPHolder, i) = i > length(S.dram_limits) ? maxlimit(S) : S.dram_limits[i]
maxlimit(S::ILPHolder) = maximum(S.dram_limits)

predict(F::Frame) = objective_value(F.model)
descriptor(F::Frame, tensor::TensorDescriptor) = F.modeltype.descriptors[tensor]

#####
##### Entry Point
#####

const _expr_type = typeof(AffExpr())

function create_model(modeltype::ILPHolder, profile_data::ProfileData)
    @timeit TO "preprocessing" preprocess!(modeltype, profile_data)

    # Start with an empty model that we will progressively build.
    model = Model(with_optimizer(Gurobi.Optimizer; TimeLimit = 600, MIPGap = 0.01))
    frame = Frame(modeltype, model, profile_data)

    # Going deep into JuMP here - the idea is to build the objective as a bunch of aff exprs
    # and eventually combine all of them together.
    model[:node_times] = Dict{String, _expr_type}()
    model[:tensor_async] = Dict{String, _expr_type}()
    model[:tensor_sync] = _expr_type()

    @timeit TO "adding tensors" add_tensors!(frame)
    @timeit TO "adding nodes" add_nodes!(frame)
    @timeit TO "adding constraints" add_constraints!(frame)

    # Default objective is to just sum all of the node times
    objective_expr = model[:tensor_sync]
    for (node_name, node_times) in model[:node_times]
        # Check to see if there are overlapping async transfers.
        #
        # If so, take the max of the sum of the overlapping transfers and the node time.
        _async = get(model[:tensor_async], node_name, nothing)
        if isnothing(_async)
            add_to_expression!(objective_expr, node_times)
        else
            var = @variable(model, integer = true, lower_bound = 0)
            @constraint(model, var >= node_times)
            @constraint(model, var >= _async)
            add_to_expression!(objective_expr, var)
        end
    end
    # Quick optimization to remove zero terms
    drop_zeros!(objective_expr)
    @objective(frame.model, Min, objective_expr)

    return frame
end

## Metadata For graph creation
@enum VertexLocation LOC_PMEM LOC_DRAM LOC_DRAM_PRE LOC_SOURCE LOC_SINK

ispmem(loc::VertexLocation) = loc == LOC_PMEM
isdram(loc::VertexLocation) = loc == LOC_DRAM || loc == LOC_DRAM_PRE
issource(loc::VertexLocation) = loc == LOC_SOURCE
issink(loc::VertexLocation) = loc == LOC_SINK

@enum EdgeType begin
    EDGE_NONE
    EDGE_SYNC_READ
    EDGE_SYNC_WRITE
    EDGE_ASYNC_READ
    EDGE_ASYNC_WRITE
end
isasync(et::EdgeType) = in(et, (EDGE_ASYNC_READ, EDGE_ASYNC_WRITE))

@enum MoveType MOVE_NONE MOVE_SYNC MOVE_ASYNC

# Metadata to assign to each node in the liveness graph for tensors.
struct VertexMetadata
    # The gadget that this vertex belongs to. Used for edge generation.
    gadget::Int
    # The op index that this gadget refers to
    op::NodeDescriptor
    # Where the vertex lives
    location::VertexLocation
    # What type of moves this vertex allows
    move_type::MoveType
    isuser::Bool
    vertex_number::Int
end

struct EdgeMetadata
    edgetype::EdgeType
end
isasync(em::EdgeMetadata) = isasync(em.edgetype)

#####
##### Preprocessing
#####

# Preprocessing basically involves creating the tensor graphs for each intermediate tensor.

function _liverange(data::ProfileData, t::TensorDescriptor)
    start = findfirst(isequal(_producer(t, data)), nodes(data))::Int
    stop = findlast(isequal(_consumer(t, data)), nodes(data))
    isnothing(stop) && (stop = length(nodes))
    return start:stop
end

function _getgadgets(A::ILPHolder{IsAsynchronous}, data::ProfileData, t::TensorDescriptor)
    liverange = _liverange(data, t)
    livenodes = (nodes(data, x) for x in liverange)
    users = _users(t, data)
    refs = Vector{NamedTuple{(:node, :move_type),Tuple{NodeDescriptor,MoveType}}}()

    # Build the referece map
    reference_map = Dict{NodeDescriptor, NodeDescriptor}()
    ref = first(users)

    # To decide if a node should be considered as an aynchronous move point, we check to see
    # if the node is with `bound` distance of a user of the tensor.
    #
    # The intuition here is that moves will probably be located closer to their producers or
    # consumers rather than further.
    #
    # Making `bound` larger increased the search space of the formulation, which may lead to
    # better results at the cost of a larger mode.
    bound = 10
    move_time = sizeof(t) / A.write_bandwidth
    for ind in liverange
        node = nodes(data, ind)
        if in(node, users)
            push!(refs, (node = node, move_type = MOVE_SYNC))
            ref = node

        # Check if there is a user node within `bound`. If so, make this an async move node.
        elseif hasprofile(node) && !is_memory_intensive(node) &&
            any(
                in(users),
                (nodes(data, i) for i in max(ind-bound, 1):min(ind+bound, length(nodes(data))))
            )

            push!(refs, (node = node, move_type = MOVE_ASYNC))
            ref = node
        end
        reference_map[node] = ref
    end

    return refs, reference_map
end

function _getgadgets(::ILPHolder{IsSynchronous}, data::ProfileData, t::TensorDescriptor)
    liverange = _liverange(data, t)
    livenodes = (nodes(data, x) for x in liverange)
    users = _users(t, data)

    # Build the referece map
    reference_map = Dict{NodeDescriptor, NodeDescriptor}()
    ref = first(users)
    for ind in liverange
        node = nodes(data, ind)
        if in(node, users)
            ref = node
        end
        reference_map[node] = ref
    end

    nt = [
        (node = u, move_type = isone(i) ? MOVE_NONE : MOVE_SYNC) for (i,u) in enumerate(users)
    ]

    return nt, reference_map
end

function _getgadgets(::ILPHolder{IsFixed}, data::ProfileData, t::TensorDescriptor)
    liverange = _liverange(data, t)
    producer = nodes(data, first(liverange))

    reference_map = Dict{NodeDescriptor, NodeDescriptor}()
    for ind in liverange
        reference_map[nodes(data, ind)] = producer
    end

    return [(node = producer, move_type = MOVE_NONE)], reference_map
end

function edge_metadata(src, dst, s, d, src_move_type)
    # Setup the correct move annotations.
    if src_move_type == MOVE_ASYNC
        edge_read_type = EDGE_ASYNC_READ
        edge_write_type = EDGE_ASYNC_WRITE
    else
        edge_read_type = EDGE_SYNC_READ
        edge_write_type = EDGE_SYNC_WRITE
    end

    # Determine if an edge should be added and what kind of edge it is.
    if (src, dst) == (LOC_SOURCE, LOC_DRAM_PRE)
        isone(d) && return EdgeMetadata(EDGE_NONE)
    elseif (src, dst) == (LOC_SOURCE, LOC_PMEM)
        isone(d) && return EdgeMetadata(EDGE_NONE)

    # LOC_DRAM as source
    elseif (src, dst) == (LOC_DRAM, LOC_DRAM)
        s == d-1 && return EdgeMetadata(EDGE_NONE)
    elseif (src, dst) == (LOC_DRAM, LOC_PMEM)
        s == d-1 && return EdgeMetadata(EDGE_NONE)
    elseif (src, dst) == (LOC_DRAM, LOC_SINK)
        s == d-1 && return EdgeMetadata(EDGE_NONE)

    # LOC_DRAM_PRE as source
    elseif (src, dst) == (LOC_DRAM_PRE, LOC_PMEM)
        s == d-1 && return EdgeMetadata(edge_write_type)
    elseif (src, dst) == (LOC_DRAM_PRE, LOC_DRAM_PRE)
        s == d-1 && return EdgeMetadata(EDGE_NONE)
    elseif (src, dst) == (LOC_DRAM_PRE, LOC_SINK)
        s == d-1 && return EdgeMetadata(EDGE_NONE)

    # LOC_PMEM as source
    elseif (src, dst) == (LOC_PMEM, LOC_DRAM)
        (s == d) && !isone(s) && return EdgeMetadata(edge_read_type)
    elseif (src, dst) == (LOC_PMEM, LOC_PMEM)
        (s == d-1) && return EdgeMetadata(EDGE_NONE)
    elseif (src, dst) == (LOC_PMEM, LOC_SINK)
        (s == d-1) && return EdgeMetadata(EDGE_NONE)
    end
    return nothing
end

function preprocess!(S::ILPHolder, data::ProfileData)
    for tensor in tensors(data)

        # Get the users of this node
        @timeit TO "making gadgets" begin
            # Get two things from _getgadgets:
            #
            # 1. A named tuple (node::NodeDescriptor, move_type::MoveType)
            # 2. A dictionary implementing the `ref` function.
            gadgets, reference_map = _getgadgets(S, data, tensor)
        end

        @assert !isempty(gadgets)

        # Graph building time :D
        g = MetaGraph(DiGraph(), EdgeMetadata, VertexMetadata)

        # Get the users so we can annotate if a gadget node is a user
        users = _users(tensor, data)

        # Add nodes for each region
        @timeit TO "creating graph vertices" for (count, nt) in enumerate(gadgets)
            # Unpacek the
            node = nt.node
            move_type = nt.move_type
            islast = (count == length(gadgets))

            isuser = in(node, users)

            if count == 1
                add_vertex!(g, VertexMetadata(0, node, LOC_SOURCE, move_type, isuser, nv(g)+1))
            end
            # Enumerate over locations that this tensor can live.
            #
            # Do it this way because some nodes can only live in DRAM, so iterating
            # then filtering takes care of that
            for location in locations(data, tensor)
                if location == DRAM
                    # Add DRAM nodes
                    add_vertex!(g, VertexMetadata(count, node, LOC_DRAM_PRE, move_type, isuser, nv(g)+1))

                    # only add a DRAM node if there could have been a write to PMEM
                    if count > 1
                        add_vertex!(g, VertexMetadata(count, node, LOC_DRAM, move_type, isuser, nv(g)+1))
                    end
                end

                if location == PMEM
                    @assert !startswith(nGraph.name(tensor), "Constant")
                    # PMEM node
                    add_vertex!(g, VertexMetadata(count, node, LOC_PMEM, move_type, isuser, nv(g)+1))
                end
            end
            if islast
                # Set the gadget number for the sink to one higher than the last count.
                add_vertex!(g, VertexMetadata(count + 1, node, LOC_SINK, move_type, isuser, nv(g)+1))
            end
        end

        # Use a quadratic complexity algorithm for doing edge assignment. It's not
        # perfect but it's simple, and as long as the graphs don't get too big should
        # run quickly enough for our purposes.
        @timeit TO "creating graph edges" for src in vertices(g), dst in vertices(g)
            src == dst && continue

            src_meta = _meta(g, src)
            dst_meta = _meta(g, dst)

            metadata = edge_metadata(
                src_meta.location,
                dst_meta.location,
                src_meta.gadget,
                dst_meta.gadget,
                src_meta.move_type,
            )

            isnothing(metadata) && continue

            add_edge!(g, src, dst, metadata)
        end

        # Create the descriptor
        S.descriptors[tensor] = TensorMeta(g, [g.node for g in gadgets], reference_map)
    end
end

#####
##### Adding Tensors
#####

function add_tensors!(frame::Frame)
    data = frame.profile_data
    modeltype = frame.modeltype

    # Create variables for the tensors and add flow constraints to the to the tensor graphs
    @variable(frame.model,
        tensor_graphs[
            tensor = tensors(data),
            e = edges(graph(descriptor(frame, tensor)))
        ],
        Bin
    )

    for tensor in tensors(data)
        g = graph(descriptor(frame, tensor))
        # Iterate through nodes in the graph - generating constraints based on the type
        # of node.
        for v in vertices(g)
            # Set flow coming out of the source node
            if _meta(g, v).location == LOC_SOURCE
                @constraint(frame.model,
                    sum(tensor_graphs[tensor, e] for e in outedges(g, v)) == 1
                )

            # Set flow going into the sink node
            elseif _meta(g, v).location == LOC_SINK
                @constraint(frame.model,
                    sum(tensor_graphs[tensor, e] for e in inedges(g, v)) == 1
                )

            # All other ops must conserve flow
            else
                oe = collect(outedges(g, v))
                ie = collect(inedges(g, v))
               @constraint(frame.model,
                   sum(tensor_graphs[tensor, e] for e in oe) - sum(tensor_graphs[tensor, e] for e in ie) == 0
               )
           end
        end
    end

    #####
    ##### Add objective penalty for moving data
    #####

    add_movement_formulations!(frame)

    #####
    ##### Create variables to determine if a tensor is in DRAM.
    #####

    @variable(frame.model,
        tensor_in_dram[
            tensor = tensors(data),
            user = name.(users(descriptor(frame, tensor)))
        ],
        Bin
    )

    @variable(frame.model,
        tensor_in_dram_post[
            tensor = tensors(data),
            user = name.(users(descriptor(frame, tensor)))
        ],
        Bin
    )

    # A tensor in DRAM is live if any of its incoming edges are used.
    for tensor in tensors(data)
        desc = descriptor(frame, tensor)
        g = graph(desc)

        for user in users(desc)
            # Get the DRAM for this op.
            verts = filter(
                v -> isdram(_meta(g,v).location) && _meta(g,v).op == user,
                vertices(g)
            )

            # Map `inedges` to `vertex_iter` and iterats over all those edges
            _iter = Iterators.flatten(inedges.(Ref(g), verts))
            for e in _iter
                @constraint(
                    frame.model,
                    tensor_in_dram[tensor, name(user)] >= tensor_graphs[tensor, e]
                )
            end

            # If all incoming edges are not taken, tensor MUST not be in DRAM.
            @constraint(frame.model,
                sum(tensor_graphs[tensor, e] for e in _iter) >=
                    tensor_in_dram[tensor, name(user)]
            )

            # Similary, set the post DRAM constraints
            _edges = filter(
                e -> (isdram(_meta(g, src(e)).location) &&
                    # Need to check "LOC_SINK" for the static case
                    (
                        isdram(_meta(g, dst(e)).location) ||
                        _meta(g, dst(e)).location == LOC_SINK
                    ) && _meta(g, src(e)).op == user),
                collect(edges(g))
            )
            for e in _edges
                @constraint(
                    frame.model,
                    tensor_in_dram_post[tensor, name(user)] >= tensor_graphs[tensor, e]
                )
            end

            @constraint(frame.model,
                sum(tensor_graphs[tensor, e] for e in _edges) >=
                    tensor_in_dram_post[tensor, name(user)]
            )
        end
    end

    return nothing
end

# Filter on edge type, sort by parent index to get the edges in execution order.
_find_edges(g, edgetype) = sort(
    filter(e -> _meta(g, e).edgetype == edgetype, collect(edges(g))),
    by = src
)

# Formulation specific move node stuff
add_movement_formulations!(frame::Frame{ILPHolder{IsFixed}}) = nothing
function add_movement_formulations!(frame::Frame)
    # Unpack variables
    data = frame.profile_data
    modeltype = frame.modeltype

    tensor_sync_expr = frame.model[:tensor_sync]
    tensor_async_dict = frame.model[:tensor_async]
    tensor_graphs = frame.model[:tensor_graphs]

    # A tensor is written to dram if:
    # - It was not created into PMEM
    # - Any edge from DRAM to PMEM is taken
    #
    # NOTE: We only pay the write cost once.
    @variable(frame.model, tensor_write[tensor = tensors(data)], Bin)

    # Add objective terms for all read ops
    for tensor in tensors(data)
        # Skip if this tensor can never be assigned to PMEM
        in(PMEM, locations(data, tensor)) || continue

        # Some unpacking
        g = graph(descriptor(frame, tensor))
        bytes = sizeof(tensor)

        read_cost = round(Int, bytes / rb(modeltype))
        write_cost = round(Int, bytes / wb(modeltype))
        read_cost_async = round(Int, bytes / rba(modeltype))
        write_cost_async = round(Int, bytes / wba(modeltype))

        # Collect Edges according to type.
        sync_reads = _find_edges(g, EDGE_SYNC_READ)
        sync_writes = _find_edges(g, EDGE_SYNC_WRITE)
        async_reads = _find_edges(g, EDGE_ASYNC_READ)
        async_writes = _find_edges(g, EDGE_ASYNC_WRITE)

        #####
        ##### Constraints for sync write variable
        #####

        # No Sync write if any async write
        for e in sync_writes
            @constraint(
                frame.model,
                tensor_write[tensor] >= tensor_graphs[tensor, e]
            )
        end

        # No sync write if no edges taken
        @constraint(
            frame.model,
            tensor_write[tensor] <= sum(tensor_graphs[tensor, e] for e in sync_writes)
        )

        #####
        ##### Constraints on async write variables
        #####

        # Assign each edge to the kernel it overlaps with.
        #
        # Just go overkill and grab all the edges, even though we end up only using a subset.
        kernels = Dict(e => _meta(g,src(e)).op for e in edges(g))

        # Create read variables expressions
        for e in async_reads
            _expr = get!(tensor_async_dict, name(kernels[e]), _expr_type())
            move_var = tensor_graphs[tensor, e]
            add_to_expression!(_expr, read_cost_async, move_var)
            dict_push!(frame.modeltype.async_move_vars, kernels[e], move_var)
        end

        # Create write variables.
        for e in async_writes
            _expr = get!(tensor_async_dict, name(kernels[e]), _expr_type())
            move_var = tensor_graphs[tensor, e]
            add_to_expression!(_expr, write_cost_async, move_var)
            dict_push!(frame.modeltype.async_move_vars, kernels[e], move_var)
        end

        #####
        ##### Finally, add all the synchonous move costs.
        #####
        for e in sync_reads
            add_to_expression!(tensor_sync_expr, read_cost, tensor_graphs[tensor, e])
        end
        add_to_expression!(tensor_sync_expr, write_cost, tensor_write[tensor])
    end
    return nothing
end

# There's an issue when trying to reference whether or not a tensor is in DRAM.
#
# If we're on an op where the tensor is used, we have to look at the inputs to a
# graph verted with LOC_DRAM or LOC_PREAD to see if the tensor was fetched or already
# lived in dram.
#
# If we're on an op where a tensor is LIVE but not READ, we need to check the outgoing
# edge of the correct DRAM -> DRAM node to see if the tensor just lives around in DRAM.
function get_tensor_in_dram(F::Frame, tensor::TensorDescriptor, node::NodeDescriptor)
    desc = descriptor(F, tensor)
    if in(node, users(desc))
        return F.model[:tensor_in_dram][tensor, nGraph.name(node)]
    else
        return F.model[:tensor_in_dram_post][tensor, nGraph.name(get_reference(desc, node))]
    end
end

function add_nodes!(F::Frame)
    data = F.profile_data

    # Create decision variables for all nodes that have a choice of backend algorithm.
    select_nodes = filter(x -> hasprofile(x) && can_select_algo(data, x), nodes(data))
    if !isempty(select_nodes)
        @info "Creating Algorithms Variables"
        @variable(
            F.model,
            algo_var[
                node = select_nodes,
                enum = get_enums(gettime(data, node))
            ],
            Bin
        )

        # Constrain so only one algorithm may be selected.
        for node in select_nodes
            @constraint(
                F.model,
                sum(algo_var[node, e] for e in get_enums(gettime(data, node))) == 1
            )
        end
    end

    for node in nodes(data)
        # We don't profile all ops, so perform a quick check to see if this is an op
        # the we have profile information for. If not, there's nothing to do as far as the
        # ILP model is concerned.
        hasprofile(node) || continue

        # The GPU path of this code will just return an all DRAM config - which will be
        # useful for generating the constraint that all kernel IO for the GPU case must
        # reside in GPU DRAM.
        #
        # The CPU path will yield a bunch of DRAM/PMEM combinations
        configs = configs_for(data, node) 

        # Create a variable for each config.
        vars = @variable(F.model, [config = configs], Bin)

        for config in configs
            # Create an expression for the input and output locations
            expr = _expr_type()
            iter = Iterators.flatten((
                zip(config.inputs, inputs(node)),
                zip(config.outputs, outputs(node))
            ))

            for (location, tensor) in iter
                # use `jump_tensor` because it's really a JuMP variable that is returned
                # by this call.
                jump_tensor = get_tensor_in_dram(F, tensor, node)
                if location == DRAM
                    add_to_expression!(expr, jump_tensor)
                    @constraint(F.model, vars[config] <= jump_tensor)
                else
                    add_to_expression!(expr, 1)
                    add_to_expression!(expr, -1, jump_tensor)
                    @constraint(F.model, vars[config] <= 1 - jump_tensor)
                end
            end

            @constraint(
                F.model, 
                vars[config] + length(config.inputs) + length(config.outputs) >= 1 + expr
            )
        end

        # Add a valid contraint to help the solver
        @constraint(F.model, sum(vars[config] for config in configs) == 1)

        # Create an expression for this node's expected running time.
        node_times = _expr_type()
        for config in configs
            # If we can select the algorithm for this node, we need to generate some more
            # variables to "AND" the config with the algorithm selection to ensure that
            # we only get a single algorithm out at the end.
            #
            # If there are not multiple algorithms, then we don't have to worry about it.
            if can_select_algo(data, node)
                v = @variable(F.model, [enum = get_enums(gettime(data, node))], Bin)
                for enum in get_enums(gettime(data, node))
                    @constraint(F.model, v[enum] <= algo_var[node, enum])
                    @constraint(F.model, v[enum] <= vars[config])
                    @constraint(F.model, v[enum] + 1 >= vars[config] + algo_var[node, enum])

                    coeff = round(Int64, gettime(data, node, config, enum))
                    add_to_expression!(node_times, coeff, v[enum])
                end
            else
                coeff = round(Int64, gettime(data, node, config))
                add_to_expression!(node_times, coeff, vars[config])
            end
        end
        F.model[:node_times][name(node)] = node_times
    end
    return nothing
end

# Allocations in ngraph happen on 4096 bytes boundaries. For better accuracty, round
# up to the nearest multiple of 4096 before figuring out the number of bytes.
#
# Take the floor to introduce more zeros into the ILP formulation. This shouldn't really
# make much of a difference.
tensor_size(t::TensorDescriptor) = tensor_size(sizeof(t))
tensor_size(sz) = ceil(Int, ceil(Int, sz / 4096) * 4096 / 1E6)

function add_constraints!(F::Frame)
    # Unpack some variables
    data = F.profile_data

    for (index, tensors) in enumerate(live_tensors(data))
        node = nodes(data, index)
        hasprofile(node) || continue
        F.modeltype.node_to_limit_index[node] = index

        # Add DRAM constraint for the workspace
        if can_select_algo(data, node)
            v = F.model[:algo_var]
            algo_expr = @expression(
                F.model, 
                sum(
                    tensor_size(get_bytes(gettime(data, node), e)) * 
                    v[node, e] for e in get_enums(gettime(data, node))
                )
            )
            @show algo_expr
        else
            algo_expr = _expr_type()
        end

        if !isempty(tensors)
            @constraint(F.model,
                algo_expr + sum(tensor_size(t) * get_tensor_in_dram(F, t, node)
                    for t in tensors
                    if !iszero(tensor_size(t))) <= limit(F, index)
            )
        end
    end

    return nothing
end


# Struct for keeping track of what tensors are moved.
#
# children: Maps a tensor `t` to the collection tensors that are the results of "Move"
#   instructions ultimately beginning at `t`.
# parent: Maps a tensor `t` to its parent tensor. The following should hold: `t ∈ children[parent[t]]`
struct TensorMap
    children::Dict{TensorDescriptor, Vector{TensorDescriptor}}
    parent::Dict{TensorDescriptor, TensorDescriptor}
end
TensorMap() = TensorMap(
    Dict{TensorDescriptor, Vector{TensorDescriptor}}(),
    Dict{TensorDescriptor, TensorDescriptor}()
)

function addtensor!(M::TensorMap, d::TensorDescriptor)
    @assert !haskey(M.children, d)
    @assert !haskey(M.parent, d)

    M.children[d] = TensorDescriptor[]
    M.parent[d] = d
end

function addchild!(M::TensorMap, parent::TensorDescriptor, child::TensorDescriptor)
    push!(M.children[parent], child)
    M.parent[child] = parent
end

getchildren(M::TensorMap, parent) = M.children[parent]
getparent(M::TensorMap, child) = M.parent[child]
isparent(M::TensorMap, tensor) = getparent(M, tensor) == tensor

#####
##### Conifiguration
#####

struct MoveAction
    consumers::Vector{NodeDescriptor}
    location::TensorLocation
    replace_incumbent::Bool
    # Additional data needed for "asynchronous" moves
    concurrent::Union{Nothing, NodeDescriptor}
end
isasync(M::MoveAction) = !isnothing(M.concurrent)

function _initial_loc(path)
    initial_location = first(path).location
    if initial_location == LOC_PMEM
        return PMEM
    elseif isdram(initial_location)
        return DRAM
    else
        error("$(initial_location)???")
    end
end

function configure!(f, frame::Frame)
    # Get initial schedules for the frame
    initial_schedule = get_schedule(frame)

    # Convert this into an appropriate format for the inner `configure!`
    schedule = Dict(
        t => (_initial_loc(path), getactions(tensor_graph, path))
        for (t, (tensor_graph, path)) in initial_schedule
    )

    # TODO: Move this into the innermost `configure!`
    data = frame.profile_data
    for node in nodes(data)
        if nGraph.Lib.can_select_algo(nGraph.getpointer(node)) 
            algo_var = frame.model[:algo_var]
            count = 0
            local algo_enum
            for enum in get_enums(gettime(data, node))
                if approx_one(algo_var[node,enum])
                    count += 1
                    algo_enum = enum
                end
            end

            # Only one algorithm should be selected
            @assert count == 1

            @show nGraph.name(node)
            @show convert(Int, algo_enum)
            @show convert(Int, get_bytes(gettime(data, node), algo_enum))
            @show get_time(gettime(data, node), algo_enum)
            
            nGraph.Lib.set_algo(
                nGraph.getpointer(node),
                convert(UInt, algo_enum),
                convert(UInt, get_bytes(gettime(data, node), algo_enum))
            )
        end
    end


    return configure!(f, frame.profile_data, schedule)
end

function configure!(fex::nGraph.FluxExecutable, data::ProfileData, schedule)
    f = fex.ex.ngraph_function
    tensor_map = configure!(f, data, schedule)

    fex = nGraph.recompile(fex)
    # Update ProfileData in Frame for the newly compiled function
    profile_data = profile(fex)

    return fex, profile_data, tensor_map
end

function configure!(fn::nGraph.NFunction, data::ProfileData, schedule, algos = nothing)
    # Unpack args
    _cleanup!(fn)

    # Get the locations of the tensors currently in the graph
    config = Dict{TensorDescriptor, TensorLocation}()

    # Process the move node chains
    tensor_map = TensorMap()

    for (tensor, (initial_location, actions)) in schedule
        addtensor!(tensor_map, tensor)
        config[tensor] = initial_location

        producer = _producer(tensor, data)
        producer_output = findonly(isequal(tensor), outputs(producer))
        incumbent = tensor

        for action in actions

            consumers = action.consumers
            consumer_inputs = [findonly(isequal(incumbent), inputs(n)) for n in consumers]

            if isasync(action)
                move_node = insert_moveasync_node!(
                    producer,
                    producer_output,
                    consumers,
                    consumer_inputs,
                    action.concurrent,
                )

                if !ismove(producer)
                    @assert data.node_to_index[producer] < data.node_to_index[action.concurrent]
                end
            else
                move_node = insert_move_node!(
                    producer,
                    producer_output,
                    consumers,
                    consumer_inputs,
                )
            end

            # Add the new output tensor tothe tensor map
            for output in outputs(move_node)
                addchild!(tensor_map, tensor, output)
            end

            # Determine associate from the action location.
            #
            # If moving to PMEM, perform this action as soon as possible after the node
            # generating the argument.
            if action.location == PMEM || isasync(action)
                nGraph.set_input_affinity(move_node)

                # If this is an asynchronous move, we want to associate it with the
                # concurrent node.
                #
                # Otherwise, associate with the producer
                if isasync(action)
                    nGraph.add_associate(move_node, name(action.concurrent))
                else
                    nGraph.add_associate(move_node, name(producer))
                end

                # Perform a sanity check. Should not move data to PMEM if it already
                # started in PMEM.
                !isasync(action) && @assert initial_location == DRAM

            # Otherwise, make this happen as late as possible. Add all of the output
            # associates to this list because scheduling may be reordered after inserting
            # the move nodes.
            elseif action.location == DRAM
                nGraph.set_output_affinity(move_node)
                for consumer in consumers
                    nGraph.add_associate(move_node, name(consumer))
                end
            else
                error()
            end

            # Add this move node to `node_dict` and assign its output tensor to the config.
            output_tensor = first(outputs(move_node))
            config[output_tensor] = action.location

            if action.replace_incumbent
                producer = move_node
                # Since we're just inserting move nodes, the output index will now always
                # be 1
                producer_output = 1
                incumbent = output_tensor
            end
        end
    end

    #####
    ##### Apply the config
    #####

    # Iterate over each node and each output tensor for each node. Each output tensor should
    # have an assigned location
    for node in fn, output in outputs(NodeDescriptor(node))
        if config[output] == PMEM
            make_persistent(output)
        end
    end

    # Set algorithms and workspaces

    return tensor_map
end

# Get the path of the tensor traced through the graph
function get_schedule(F::Frame)
    data = F.profile_data
    model_graphs = F.model[:tensor_graphs]

    schedule = Dict{TensorDescriptor, Tuple{MetaGraph, Vector{VertexMetadata}}}()

    for tensor in tensors(data)
        g = graph(descriptor(F, tensor))

        # Trace the route taken through the graph
        v = find_vertex(g, (g, v) -> _meta(g, v).location == LOC_SOURCE)

        path = [_meta(g, v)]
        seen = Int[]
        while _meta(g, v).location != LOC_SINK
            if isempty(outedges(g, v)) || in(v, seen)
                error("""
                $tensor
                $(_meta(g, v))
                """)
            end

            push!(seen, v)
            for e in outedges(g, v)
                if approx_one(model_graphs[tensor, e])
                    v = dst(e)
                    break
                end
            end
            push!(path, _meta(g, v))
        end
        # Drop the first source element and last sink element
        popfirst!(path)
        pop!(path)

        schedule[tensor] = (g, path)
    end

    return schedule
end

# Consume all of the PKEEP nodes.
function getkeeps(vertices::Vector{VertexMetadata}, index)
    keeps = NodeDescriptor[]
    while checkbounds(Bool, vertices, index) && isdram(vertices[index].location)
        vertex = vertices[index]
        if vertex.isuser
            push!(keeps, vertices[index].op)
        end
        index += 1
    end
    return unique(keeps)
end

function isasync(tensor_graph, a::VertexMetadata, b::VertexMetadata)
    # Get the vertex number from the metadata - construct the edge
    src = a.vertex_number
    dst = b.vertex_number
    edge_metadata = _meta(tensor_graph, edgetype(tensor_graph)(src, dst))
    return isasync(edge_metadata)
end

# Return `true` if there is an implied write to
write_to_pmem(a, b) = a == LOC_DRAM_PRE && ispmem(b)
read_from_pmem(a, b) = ispmem(a) && isdram(b)

function getactions(tensor_graph, vertices::Vector{VertexMetadata})
    actions = MoveAction[]
    written_to_pmem = false

    for i in Iterators.drop(eachindex(vertices), 1)
        src = vertices[i-1]
        dst = vertices[i]
        a, b = src.location, dst.location

        # Determine whether this is an asynchronous move
        if isasync(tensor_graph, src, dst)
            concurrent = src.op
        else
            concurrent = nothing
        end

        if write_to_pmem(a, b)
            if written_to_pmem
                @show actions
                error()
            end
            # All downstream users are consumers
            consumers = unique(vertices[i].op for i in i:length(vertices) if vertices[i].isuser)

            # One solution to the ILP is to move data back and forth if it does not cause
            # any additional overhead.
            #
            # Here, we just filter out these movements by checking if the consumers of a
            # move is empty
            if !isempty(consumers)
                push!(actions, MoveAction(consumers, PMEM, true, concurrent))
                written_to_pmem = true
            end
        end

        if read_from_pmem(a, b)
            consumers = getkeeps(vertices, i)
            if !isempty(consumers)
                push!(actions, MoveAction(consumers, DRAM, false, concurrent))
            end
        end
    end

    # Need to filter out the first op from showing up in the actions because the first op
    # doesn't actually use the tensor - it produces it.
    producing_op = first(vertices).op

    for action in actions
        filter!(!isequal(producing_op), action.consumers)
    end
    return actions
end

#####
##### Misc Stuff
#####

estimate_move_time(fex::nGraph.FluxExecutable, frame::Frame) = zero(Float64)
function estimate_move_time(fex::nGraph.FluxExecutable, frame::Frame{ILPHolder{IsSynchronous}})
    move_time = zero(Float64)
    for _node in fex.ex.ngraph_function
        node = NodeDescriptor(_node)

        # If this is a move, determine which direction data is being moved and add the move
        # time estimate to the rolling counter.
        if description(node) == "Move"
            tensor = first(outputs(node))
            if nGraph.is_persistent(tensor)
                move_time += sizeof(tensor) / wb(frame.modeltype)
            else
                move_time += sizeof(tensor) / rb(frame.modeltype)
            end
        end
    end
    return move_time
end


# your moves are weak
function profile_moves(fex)
    timing_data = read_timing_data(fex.ex.ngraph_function)
    computed_stats = Dict{String, NamedTuple}()
    for node_unwrapped in fex.ex.ngraph_function
        node = NodeDescriptor(node_unwrapped)
        ismove(node) || continue

        time = timing_data[findfirst(x -> x["name"] == name(node), timing_data)]["dur"]
        # Convert bytes to GB, time from μs to s
        bytes = sizeof(first(inputs(node)))
        bandwidth = (bytes / 1E9) / (time / 1E6)
        computed_stats[name(node)] = (
            bytes = bytes,
            bandwidth = bandwidth,
            write_to_pmem = !nGraph.is_persistent(first(inputs(node))),
        )
    end

    # Summarize read and write bandwidth
    println("Read Bandwidths")
    for f in (ismoveasync, !ismoveasync)
        s = 0
        count = 0
        for (node_name, stats) in computed_stats
            f(node_name) || continue
            if stats.write_to_pmem == false
                println("$node_name => $(stats.bandwidth) GB/s")
                println("    size: $(stats.bytes) B")

                if !isinf(stats.bandwidth)
                    s += stats.bandwidth
                    count += 1
                end
            end
        end

        println()
        println("Average Bandwidth: ", s / count)
        println()
    end
    println()
    println("Write Bandwidths")
    for f in (ismoveasync, !ismoveasync)
        s = 0
        count = 0
        for (node_name, stats) in computed_stats
            f(node_name) || continue
            if stats.write_to_pmem == true
                println("$node_name => $(stats.bandwidth) GB/s")
                println("    size: $(stats.bytes) B")

                if !isinf(stats.bandwidth)
                    s += stats.bandwidth
                    count += 1
                end
            end
        end
        println()
        println("Average Bandwidth: ", s / count)
        println()
    end

    return computed_stats
end
