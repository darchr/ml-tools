standard_filter(x, size = 4) =  !(MemSnoop.executable(x)) &&
                                (MemSnoop.readable(x) || MemSnoop.writable(x)) &&
                                MemSnoop.longerthan(x, size)

standard_filter(size::Integer) = x -> standard_filter(x, size) 

# Helper functions
isnothing(x) = false
isnothing(::Nothing) = true

"""
    isrunning(container::Container) -> Bool

Return `true` if `container` is running.
"""
function isrunning(container::Container)
    # List the containers, filter on ID. Should only get one result.
    filters = Dict("id" => [DockerX.getid(container)])
    list = DockerX.list_containers(all = true, filters = filters)
    @assert length(list) == 1

    return first(list).params["State"] == "running"
end

"""
    getpid(container::Container)

Return the `PID` of `container`.
"""
function Base.getpid(container::Container)
    data = DockerX.inspect(container)
    return data[k"State/Pid"]
end 

"""
    bind(a, b) -> String

Create a docker volume binding string for paths `a` and `b`.
"""
bind(a, b) = join((a, b), ":")

"""
    uid()

Return the user ID of the current user.
"""
uid() = chomp(read(`id -u`, String))

dash(x) = "--$x"
argify(a, b::Nothing, delim) = dash(a)
argify(a, b, delim) = join((dash(a), b), delim)

argify(a, b::Nothing) = (dash(a),)
argify(a, b) = (dash(a), b)

makeargs(nt::NamedTuple, delim) = [argify(a,b,delim) for (a,b) in pairs(nt)]
makeargs(nt::NamedTuple) = collect(flatten(argify(a,b) for (a,b) in pairs(nt)))
