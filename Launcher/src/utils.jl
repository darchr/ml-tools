# Helper functions
isnothing(x) = false
isnothing(::Nothing) = true

"""
    Launcher.isrunning(container::Container) -> Bool

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
    Launcher.getpid(container::Container)

Return the `PID` of `container`.
"""
function Base.getpid(container::Container)
    data = Docker.inspect(container)
    return data["State"]["Pid"]
end 

"""
    Launcher.bind(a, b) -> String

Create a docker volume binding string for paths `a` and `b`.
"""
bind(a, b) = join((a, b), ":")

"""
    Launcher.uid()

Return the user ID of the current user.
"""
uid() = chomp(read(`id -u`, String))

"""
    Launcher.username()

Return the name of the current user.
"""
username() = ENV["USER"]

# Magic to turn named tuples into strings :)
hyphenate(x::Symbol) = replace(String(x), "___" => "-")
hyphenate(x) = x

prefix(x, pre) = "$(pre)$(hyphenate(x))"

argify(a, b::Nothing, delim, pre) = (prefix(a, pre),)
argify(a, b, delim, pre) = (join((prefix(a, pre), b), delim),)

argify(a, b::Nothing, delim::Nothing, pre) = (prefix(a, pre),)
argify(a, b, delim::Nothing, pre) = (prefix(a, pre), b)

makeargs(@nospecialize(nt::NamedTuple); delim = nothing, pre = "--") = collect(flatten(argify(a, b, delim, pre) for (a,b) in pairs(nt)))
