standard_filter(x, size = 4) =  !(SystemSnoop.executable(x)) &&
                                (SystemSnoop.readable(x) || SystemSnoop.writable(x)) &&
                                SystemSnoop.longerthan(x, size)

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
username() = ENV["USER"]


hyphenate(x) = replace(String(x), "___" => "-")
prefix(x, pre) = "$(pre)$(hyphenate(x))"

argify(a, b::Nothing, delim, pre) = (prefix(a, pre),)
argify(a, b, delim, pre) = (join((prefix(a, pre), b), delim),)

argify(a, b::Nothing, delim::Nothing, pre) = (prefix(a, pre),)
argify(a, b, delim::Nothing, pre) = (prefix(a, pre), b)

makeargs(@nospecialize(nt::NamedTuple); delim = nothing, pre = "--") = collect(flatten(argify(a, b, delim, pre) for (a,b) in pairs(nt)))


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
        SystemSnoop.save(S.filename, trace)
        S.nextsave = time + S.increment
    end
end
