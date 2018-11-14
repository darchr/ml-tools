# Methods for working with stats
#
# Docker Stats

"""
    getstats(container::Container; sleepinterval = 0)

Get JSON stats from the docker daemon for `container` every `sleepinterval` seconds.
See <https://docs.docker.com/config/containers/runmetrics/> for a break down of what stats
are available and how the JSON dictionary is structures.
"""
function getstats(container::Container; sleepinterval = 0)
    # Check if the container is running.
    stats = Dict{String,Any}[] 
    while isrunning(container)
        push!(stats, DockerX.stats(container))
        if sleepinterval > 0
            sleep(sleepinterval)
        end
    end
    return stats
end

"""
    KeyChain{T}

Wrapper for an arbitrary number of string arguments representing successive keys into a 
nested JSON dictionary.

```jldoctest
julia> chain = Launcher.k"a/b/c"
Launcher.KeyChain{3}(("a", "b", "c"))

julia> d = Dict("a" => Dict("b" => Dict("c" => "hello")))
Dict{String,Dict{String,Dict{String,String}}} with 1 entry:
  "a" => Dict("b"=>Dict("c"=>"hello"))

julia> d[chain]
"hello"
```
"""
struct KeyChain{N}
    keys::NTuple{N,String}
end

macro k_str(str)
    keys = split(str, "/")
    return quote
        KeyChain(($(string.(keys)...),))
    end
end

function Base.getindex(d::Dict, chain::KeyChain)
    for k in chain.keys
        d = d[k]
    end
    return d
end

# Methods for working with the stats
# Use the total_ methods in the memory to include spawned processes if any
memory_usage(x)     = x[k"memory_stats/usage"]
rss(x)              = x[k"memory_stats/stats/total_rss"]
pgfault(x)          = x[k"memory_stats/stats/total_pgfault"]
active_anon(x)      = x[k"memory_stats/stats/total_active_anon"]
pgpgin(x)           = x[k"memory_stats/stats/total_pgpgin"]
pgpgout(x)          = x[k"memory_stats/stats/total_pgpgout"]
inactive_anon(x)    = x[k"memory_stats/stats/total_inactive_anon"]
