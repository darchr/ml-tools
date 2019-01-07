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
    filters = Dict("id" => [Docker.getid(container)])
    list = Docker.list_containers(all = true, filters = filters)
    @assert length(list) == 1

    return first(list).params["State"] == "running"
end

"""
    getpid(container::Container)

Return the `PID` of `container`.
"""
function Base.getpid(container::Container)
    data = Docker.inspect(container)
    return data["State"]["Pid"]
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

_prefix(x, prefix) = "$(prefix)$(x)"
argify(a, b::Nothing, delim, prefix) = (_prefix(a, prefix),)
argify(a, b, delim, prefix) = (join((_prefix(a, prefix), b), delim),)

argify(a, b::Nothing, delim::Nothing, prefix) = (_prefix(a, prefix),)
argify(a, b, delim::Nothing, prefix) = (_prefix(a, prefix), b)

makeargs(@nospecialize(nt::NamedTuple); delim = nothing, prefix = "--") = collect(flatten(argify(a, b, delim, prefix) for (a,b) in pairs(nt)))


#####
##### Common callbacks
#####

"""
PeriodicSave(filename::String, increment::TimePeriod)

Callback for [`run`] that saves trace data to `filename` every `increment`.
"""
mutable struct PeriodicSave
    increment::TimePeriod
    nextsave::DateTime
    filename::String
end

PeriodicSave(filename::String, increment::TimePeriod) = 
    PeriodicSave(increment, now() + increment, filename)

function (S::PeriodicSave)(process, trace, measurements)
    time = now()
    if time > S.nextsave
        @info "[$time] Saving Data"
        MemSnoop.save(S.filename, trace)
        S.nextsave = time + S.increment
    end
end
