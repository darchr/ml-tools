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
    users::Vector{NodeWrapper}

    # Look-up a node wrapper, get the node that serves as a reference for this
    reference_map::Dict{NodeWrapper, NodeWrapper}
end

get_reference(S::TensorMeta, node::NodeWrapper) = S.reference_map[node]
graph(S::TensorMeta) = S.graph
users(S::TensorMeta) = S.users

#####
##### Model Types
#####

abstract type SubModelType <: ModelType end

# Static: Assigns tensors to either PMEM or DRAM. No movement
mutable struct Static <: SubModelType
    dram_limit::Int64
    descriptors::Dict{TensorWrapper, TensorMeta}
end
Static(a) = Static(a, Dict{TensorWrapper,TensorMeta}())

# Synchronous: Can move, but cannot overlap movement with computation
mutable struct Synchronous <: SubModelType
    dram_limit::Int64
    read_bandwidth::Int64
    write_bandwidth::Int64

    # Metadata to help model creation

    # The names of all tensors in the function
    descriptors::Dict{TensorWrapper, TensorMeta}
end
Synchronous(a,b,c) = Synchronous(a,b,c, Dict{TensorWrapper,TensorMeta}())

# Asynchronous: Can overlap movcement with computation
mutable struct Asynchronous <: SubModelType
    dram_limit::Int64
    read_bandwidth::Int64
    write_bandwidth::Int64

    descriptors::Dict{TensorWrapper, TensorMeta}
end
Asynchronous(args...) = Asynchronous(args..., Dict{TensorWrapper, TensorMeta}())

# Common Methods
limit(S::SubModelType) = S.dram_limit
predict(F::Frame{<:SubModelType}) = objective_value(F.model)
descriptor(F::Frame{<:SubModelType}, tensor::TensorWrapper) = F.modeltype.descriptors[tensor]

#####
##### Entry Point
#####

const _expr_type = typeof(AffExpr())

create_model(modeltype::Synchronous, profile_data::ProfileData{AllTensors}) = error("""
Synchronous model not implemented yet for all tensors.
""")

function create_model(modeltype::SubModelType, profile_data::ProfileData{OnlyIntermediate})
    @timeit TO "preprocessing" preprocess!(modeltype, profile_data)

    # Start with an empty model that we will progressively build.
    model = Model(with_optimizer(Gurobi.Optimizer; TimeLimit = 300, MIPGap = 0.001))
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
            println("Applying Overlap Constraint for $node_name")

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
@enum VertexLocation LOC_PMEM LOC_DRAM LOC_SOURCE LOC_SINK
@enum EdgeType begin
    EDGE_NONE
    EDGE_SYNC_READ
    EDGE_SYNC_WRITE
    EDGE_ASYNC_READ
    EDGE_ASYNC_WRITE
end
@enum MoveType MOVE_NONE MOVE_SYNC MOVE_ASYNC

# Metadata to assign to each node in the liveness graph for tensors.
struct VertexMetadata
    # The gadget that this vertex belongs to. Used for edge generation.
    gadget::Int
    # The op index that this gadget refers to
    op::NodeWrapper
    # Where the vertex lives
    location::VertexLocation
    # What type of moves this vertex allows
    move_type::MoveType
end

struct EdgeMetadata
    edgetype::EdgeType
end

#####
##### Preprocessing
#####

# Preprocessing basically involves creating the tensor graphs for each intermediate tensor.

function _liverange(data::ProfileData, t::TensorWrapper)
    start = findfirst(isequal(_producer(t, data)), nodes(data))::Int
    stop = findlast(isequal(_consumer(t, data)), nodes(data))
    isnothing(stop) && (stop = length(nodes))
    return start:stop
end

function _getgadgets(A::Asynchronous, data::ProfileData, t::TensorWrapper)
    liverange = _liverange(data, t)
    livenodes = (nodes(data, x) for x in liverange)
    users = _users(t, data)
    refs = Vector{NamedTuple{(:node, :move_type),Tuple{NodeWrapper,MoveType}}}()

    # Build the referece map
    reference_map = Dict{NodeWrapper, NodeWrapper}()
    ref = first(users)
    bound = 5

    move_time = sizeof(t) / A.write_bandwidth
    for ind in liverange
        node = nodes(data, ind)
        if in(node, users)
            push!(refs, (node = node, move_type = MOVE_SYNC))
            ref = node

        # Check if there is a user node within `bound`. If so, make this an async move node.
        elseif hasprofile(node) && 
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

function _getgadgets(::Synchronous, data::ProfileData, t::TensorWrapper)
    liverange = _liverange(data, t)
    livenodes = (nodes(data, x) for x in liverange)
    users = _users(t, data)

    # Build the referece map
    reference_map = Dict{NodeWrapper, NodeWrapper}()
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

function _getgadgets(::Static, data::ProfileData, t::TensorWrapper)
    liverange = _liverange(data, t)
    producer = nodes(data, first(liverange))

    reference_map = Dict{NodeWrapper, NodeWrapper}()
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
    if (src, dst) == (LOC_SOURCE, LOC_DRAM)
        isone(d) && return EdgeMetadata(EDGE_NONE)
    elseif (src, dst) == (LOC_SOURCE, LOC_PMEM)
        isone(d) && return EdgeMetadata(EDGE_NONE)
    # LOC_DRAM as source
    elseif (src, dst) == (LOC_DRAM, LOC_DRAM)
        s == d-1 && return EdgeMetadata(EDGE_NONE)
    elseif (src, dst) == (LOC_DRAM, LOC_PMEM)
        s == d-1 && return EdgeMetadata(edge_write_type)
    elseif (src, dst) == (LOC_DRAM, LOC_SINK)
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

function preprocess!(S::SubModelType, data::ProfileData)

    for tensor in tensors(data)
        # Get the users of this node
        @timeit TO "making gadgets" begin
            # Get two things from _getgadgets:
            #
            # 1. A named tuple (node::NodeWrapper, move_type::MoveType)
            # 2. A dictionary implementing the `ref` function.
            users, reference_map = _getgadgets(S, data, tensor)
        end

        @assert !isempty(users)

        # Graph building time :D
        g = MetaGraph(DiGraph(), EdgeMetadata, VertexMetadata)

        # Add nodes for each region
        @timeit TO "creating graph vertices" for (count, nt) in enumerate(users)
            # Unpacek the
            node = nt.node
            move_type = nt.move_type
            islast = (count == length(users))

            if count == 1
                #add_vertex!(g, :metadata, VertexMetadata(0, node, LOC_SOURCE))
                add_vertex!(g, VertexMetadata(0, node, LOC_SOURCE, move_type))
            end
            # Enumerate over locations that this tensor can live.
            #
            # Do it this way because some nodes can only live in DRAM, so iterating
            # then filtering takes care of that
            for location in locations(data, tensor)
                if location == DRAM
                    # Add DRAM node
                    add_vertex!(g, VertexMetadata(count, node, LOC_DRAM, move_type))
                end

                if location == PMEM
                    # Add pre and post PMEM nodes
                    add_vertex!(g, VertexMetadata(count, node, LOC_PMEM, move_type))
                end
            end
            if islast
                # Set the gadget number for the sink to one higher than the last count.
                add_vertex!(g, VertexMetadata(count + 1, node, LOC_SINK, move_type))
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
        S.descriptors[tensor] = TensorMeta(g, [u.node for u in users], reference_map)
    end
end

#####
##### Adding Tensors
#####

function add_tensors!(frame::Frame{<:SubModelType})
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

    # A tensor in DRAM is live if any of its incoming edges are used.
    for tensor in tensors(data)
        desc = descriptor(frame, tensor)
        g = graph(desc)

        for user in users(desc)
            # Get the DRAM and PREAD vertices for this op.
            vertex = find_vertex(
                g,
                (g,v) -> _meta(g, v).location == LOC_DRAM && _meta(g, v).op == user
            )

            # Map `inedges` to `vertex_iter` and iterats over all those edges
            for e in inedges(g, vertex)
                @constraint(
                    frame.model, 
                    tensor_in_dram[tensor, name(user)] >= tensor_graphs[tensor, e]
                )
            end

            # If all incoming edges are not taken, tensor MUST not be in DRAM.
            @constraint(frame.model,
                sum(tensor_graphs[tensor, e] for e in inedges(g, vertex)) >=
                    tensor_in_dram[tensor, name(user)]
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
add_movement_formulations!(frame::Frame{Static}) = nothing
function add_movement_formulations!(frame::Frame{<:SubModelType})
    data = frame.profile_data

    tensor_sync_expr = frame.model[:tensor_sync]
    tensor_async_dict = frame.model[:tensor_async]

    tensor_graphs = frame.model[:tensor_graphs]
    read_bandwidth = frame.modeltype.read_bandwidth
    write_bandwidth = frame.modeltype.write_bandwidth

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

        read_cost = round(Int, bytes / read_bandwidth)
        write_cost = round(Int, bytes / write_bandwidth)

        # Collect Edges according to type.
        sync_reads = _find_edges(g, EDGE_SYNC_READ)
        sync_writes = _find_edges(g, EDGE_SYNC_WRITE)
        async_reads = _find_edges(g, EDGE_ASYNC_READ)
        async_writes = _find_edges(g, EDGE_ASYNC_WRITE)
        starts_in_pmem = find_edge(g,
            (g,e) ->
                _meta(g, src(e)).location == LOC_SOURCE &&
                _meta(g, dst(e)).location == LOC_PMEM
        )

        #####
        ##### Constraints for sync write variable
        #####

        # No Sync write if any async write
        for e in sync_writes
            # gather up all the asynchronous write variables
            if isempty(async_writes)
                _expr = 0
            else
                _expr = @expression(
                    frame.model,
                    sum(tensor_graphs[tensor, x] for x in async_writes)
                )
            end
            @constraint(
                frame.model, 
                tensor_write[tensor] >= tensor_graphs[tensor, e] - tensor_graphs[tensor, starts_in_pmem] - _expr
            )
        end

        # No sync write if no edges taken
        @constraint(
            frame.model,
            tensor_write[tensor] <= sum(tensor_graphs[tensor, e] for e in sync_writes)
        )

        # No sync write if tensor starts in PMEM
        @constraint(
            frame.model,
            tensor_write[tensor] <= 1 - tensor_graphs[tensor, starts_in_pmem]
        )

        #####
        ##### Constrants on async write variables
        #####

        # Assign each edge to the kernel it overlaps with.
        #
        # Just go overkill and grab all the edges, even though we end up only using a subset.
        kernels = Dict(e => _meta(g,src(e)).op for e in edges(g))

        # Create read variables expressions
        for e in async_reads
            _expr = get!(tensor_async_dict, name(kernels[e]), _expr_type())
            add_to_expression!(_expr, read_cost, tensor_graphs[tensor, e])
        end

        # Create write variables.
        #
        # Because these are created in order, we can just iterate through sequentially.
        gen_vars = VariableRef[]
        for e in async_writes
            var = @variable(frame.model, binary = true)
            @constraint(frame.model, var <= tensor_graphs[tensor, e])
            if isempty(gen_vars)
                @constraint(frame.model, var >= tensor_graphs[tensor, e] - tensor_write[tensor])
            else
                @constraint(
                    frame.model,
                    var >= tensor_graphs[tensor, e] - tensor_write[tensor] - sum(gen_vars)
                )
            end
            push!(gen_vars, var)

            # Add this move cost
            _expr = tensor_async_dict[name(kernels[e])]
            add_to_expression!(_expr, write_cost, var)
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
function get_tensor_in_dram(F::Frame{<:SubModelType}, tensor::TensorWrapper, node::NodeWrapper)
    desc = descriptor(F, tensor)

    if in(node, users(desc))
        return F.model[:tensor_in_dram][tensor, name(node)]
    else
        ref = get_reference(desc, node)
        edge = find_edge(
            desc.graph,
            # Source vertex must be in DRAM.
            # Destination can be in DRAM or SINK.
            #
            # We expect the SINK case to only apply the Static case.
            (g,e) -> _meta(g, src(e)).location == LOC_DRAM &&
                _meta(g, src(e)).op == ref &&
                in(_meta(g, dst(e)).location, (LOC_DRAM, LOC_SINK))
        )

        # Return the edge in question
        return F.model[:tensor_graphs][tensor, edge]
    end
end

function add_nodes!(F::Frame{<:SubModelType})
    data = F.profile_data

    for node in nodes(data)
        # We don't profile all ops, so perform a quick check to see if this is an op
        # the we have profile information for. If not, there's nothing to do as far as the
        # ILP model is concerned.
        hasprofile(node) || continue

        configs = collect(keys(node.timings))

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

            @constraint(F.model, vars[config] + length(config.inputs) + length(config.outputs) >=
                1 + expr)

        end
        # here, we're adding a valid contraint to help the solver
        @constraint(F.model, sum(vars[config] for config in configs) == 1)

        # Create an expression for this node's expected running time.
        node_times = _expr_type()
        for config in configs
            # For now, just use the Mean
            coeff = round(Int64, minimum(node.timings[config]))
            add_to_expression!(node_times, coeff, vars[config])
        end
        F.model[:node_times][name(node)] = node_times
    end
    return
end

# Allocations in ngraph happen on 4096 bytes boundaries. For better accuracty, round
# up to the nearest multiple of 4096 before figuring out the number of bytes.
#
# Take the floor to introduce more zeros into the ILP formulation. This shouldn't really
# make much of a difference.
tensor_size(t::TensorWrapper) = tensor_size(sizeof(t))
tensor_size(sz) = floor(Int, ceil(Int, sz / 4096) * 4096 / 1E6)

function add_constraints!(F::Frame{<:SubModelType})
    # Unpack some variables
    data = F.profile_data

    for (index, tensors) in enumerate(live_tensors(data))
        node = nodes(data, index)
        hasprofile(node) || continue

        if !isempty(tensors)
            @constraint(F.model,
                sum(tensor_size(t) * get_tensor_in_dram(F, t, node)
                    for t in tensors
                    if !iszero(tensor_size(t))) <= limit(F)
            )
        end
    end

    return
end

#####
##### Conifiguration
#####

struct MoveAction
    consumers::Vector{NodeWrapper}
    location::TensorLocation
    replace_incumbent::Bool
end

configure!(fex::nGraph.FluxExecutable, frame::Frame{Asynchronous}) = fex, nothing

function configure!(fex::nGraph.FluxExecutable, frame::Frame{<:SubModelType})
    # Unpack args
    data = frame.profile_data
    tensor_graphs = frame.model[:tensor_graphs]
    fn = fex.ex.ngraph_function
    _cleanup!(fn)

    # Get the locations of the tensors currently in the graph
    config = Dict{TensorWrapper, TensorLocation}()

    # Process the move node chains
    schedule = get_schedule(frame)
    action_map = Dict{TensorWrapper, Vector{MoveAction}}()

    for (tensor, vertices) in schedule
        initial_location = first(vertices).location
        if initial_location == LOC_PMEM
            config[tensor] = PMEM
        elseif initial_location == LOC_DRAM
            config[tensor] = DRAM
        else
            error("$(initial_location)???")
        end

        # Get a list of move actions that we will have to perform.
        actions = getactions(vertices)
        action_map[tensor] = actions

        producer = _producer(tensor, data)
        producer_output = _find(isequal(tensor), outputs(producer))

        for action in actions
            consumers = action.consumers
            consumer_inputs = [_find(isequal(tensor), inputs(n)) for n in consumers]

            move_node = insert_move_node!(producer, producer_output, consumers, consumer_inputs)

            # Determine associate from the action location.
            #
            # If moving to PMEM, perform this action as soon as possible after the node
            # generating the argument.
            if action.location == PMEM
                nGraph.set_input_affinity(unwrap(move_node))
                nGraph.add_associate(unwrap(move_node), name(producer))

                # Perform a sanity check. Should not move data to PMEM if it already
                # started in PMEM.
                @assert initial_location == LOC_DRAM

            # Otherwise, make this happen as late as possible. Add all of the output
            # associates to this list because scheduling may be reordered after inserting
            # the move nodes.
            elseif action.location == DRAM
                nGraph.set_output_affinity(unwrap(move_node))
                for consumer in consumers
                    nGraph.add_associate(unwrap(move_node), name(consumer))
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
                tensor = output_tensor
            end
        end
    end

    @assert action_verification(frame.modeltype, action_map)

    #####
    ##### Apply the config
    #####

    nGraph.get_ordered_ops!(fn)

    # Iterate over each node and each output tensor for each node. Each output tensor should
    # have an assigned location
    for node in fn, output in outputs(NodeWrapper(node))
        if config[output] == PMEM
            make_persistent(fex, data, output)
        end
    end

    fex = nGraph.recompile(fex)

    #####
    ##### Now, we do some checking to make sure everything is scheduled correctly
    #####
    #verify_moves(fex, move_nodes_created)

    return fex, action_map
end

# For the static formulation, we must make sure that no move ops were emitted
action_verification(::Static, action_map) = all(isempty, values(action_map))
action_verification(::SubModelType, action_map) = true

# Get the path of the tensor traced through the graph
function get_schedule(F::Frame{<:SubModelType})
    data = F.profile_data
    model_graphs = F.model[:tensor_graphs]

    schedule = Dict{TensorWrapper, Vector{VertexMetadata}}()

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

        schedule[tensor] = path
    end

    return schedule
end

# Consume all of the PKEEP nodes.
function getkeeps(vertices::Vector{VertexMetadata}, index)
    keeps = NodeWrapper[]
    while checkbounds(Bool, vertices, index) && vertices[index].location == LOC_DRAM
        push!(keeps, vertices[index].op)
        index += 1
    end
    return unique(keeps)
end

# Return `true` if there is an implied write to
write_to_pmem(a, b) = a == LOC_DRAM && b == LOC_PMEM
read_from_pmem(a, b) = a == LOC_PMEM && b == LOC_DRAM

function getactions(vertices::Vector{VertexMetadata})
    actions = MoveAction[]

    data_in_pmem = false
    isfirst = true

    for i in Iterators.drop(eachindex(vertices), 1)
        a, b = vertices[i-1].location, vertices[i].location

        # If we're on the first iteration and the location of `b` is PMEM, then we
        # will never write to PMEM
        if isfirst
            if a == LOC_PMEM
                data_in_pmem = true
            end
            isfirst = false
        end

        if !data_in_pmem && write_to_pmem(a, b)
            # All downstream users are consumers
            consumers = unique(vertices[i].op for i in i:length(vertices))
            push!(actions, MoveAction(consumers, PMEM, true))
            data_in_pmem = true
        end

        if read_from_pmem(a, b)
            consumers = getkeeps(vertices, i)
            push!(actions, MoveAction(consumers, DRAM, false))
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

estimate_move_time(fex::nGraph.FluxExecutable, frame::Frame{Static}) = zero(Float64)
function estimate_move_time(fex::nGraph.FluxExecutable, frame::Frame{Synchronous})
    # Get the read and write bandwidths from the frame.
    write_bandwidth = frame.modeltype.write_bandwidth
    read_bandwidth = frame.modeltype.read_bandwidth

    move_time = zero(Float64)
    for _node in fex.ex.ngraph_function
        node = NodeWrapper(_node)
        if description(node) == "Move"
            tensor = first(outputs(node))
            if is_persistent(tensor)
                move_time += sizeof(tensor) / write_bandwidth
            else
                move_time += sizeof(tensor) / read_bandwidth
            end
        end
    end
    return move_time
end


# your moves are weak
function profile_moves(fex, args, move_nodes::Dict)
    timing_data = read_timing_data(fex.ex.ngraph_function)
    computed_stats = Dict{String, NamedTuple}()
    for (node_name, stats) in move_nodes
        time = timing_data[findfirst(x -> x["name"] == node_name, timing_data)]["dur"]
        # Convert bytes to GB, time from μs to s
        bandwidth = (stats.bytes / 1E9) / (time / 1E6)
        computed_stats[node_name] = merge(stats, (bandwidth = bandwidth, ))
    end

    # Summarize read and write bandwidth
    println("Read Bandwidths")
    for (node_name, stats) in computed_stats
        if stats.write_to_pmem == false
            println("$node_name => $(stats.bandwidth) GB/s")
            println("    size: $(stats.bytes) B")
        end
    end
    println()
    println("Write Bandwidths")
    for (node_name, stats) in computed_stats
        if stats.write_to_pmem == true
            println("$node_name => $(stats.bandwidth) GB/s")
            println("    size: $(stats.bytes) B")
        end
    end

    return computed_stats
end
