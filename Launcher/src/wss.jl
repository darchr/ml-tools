# Code for invoking the wss.pl dependency.

abstract type WSSTool end

# No wss monitoring
struct NoWSS <: WSSTool end
monitor(::NoWSS, args...; kw...) = NamedTuple()

# C tool
struct WSSv2 <: WSSTool end
getpath(::WSSv2) = joinpath(PKGDIR, "deps", "wss-v2")

# PERL tool
struct WSSpl <: WSSTool end
getpath(::WSSpl) = joinpath(PKGDIR, "deps", "wss", "wss.pl" )
 
# Format of returned response:
# 
# Watching PID 27841 page references during 10 seconds...
# Est(s)     RSS(MB)    PSS(MB)    Ref(MB)
# 10.162     2861.91    2861.91    1699.94
# 

function parsedata(::WSSpl, str::String)
    # Get a approximate time stamp
    timestamp = now()
    timestamp

    # Wrap the string in an IOBuffer so we can iterate through lines.
    # Drop the first 2 lines because we don't really care about them.
    buf = IOBuffer(str) 
    readline(buf)
    readline(buf)

    # Third line containes the data we want.
    data = parse.(Float64, split(readline(buf), r"\s+"))

    # Create a named tuple for the results.
    return (
        timestamp = timestamp,
        est = data[1],
        rss = data[2],
        pss = data[3],
        ref = data[4],
    )
end

"""
    getstats(::WSSv2, pid; sleeptime = 0, duration = 10)

Use the `wss=v2` tool to estimate the working set size of `pid` for as long as `pid` is 
active. Returns two equal lenght vectors: the first is the estimated WSS sizes and the 
second is the corresponding approximate time stamps of the measurements.

Keywords
--------
* `sleeptime` - The time to sleep between measurements. Default: `0`
* `duration` - The time overwhich to take a measurement. Default: `10`
"""
function getstats(wss::WSSTool, pid; sleeptime = 0, duration = 10)
    # Get the path to the wss-v2 executable
    path = getpath(wss)   

    samples = NamedTuple[]
    try
        # Once the process gets killed, wss should exit with a nonzero status. The `read`
        # command will throw an error, at which point we clean up and return the vector
        # of sizes.
        while true
            # Invoke WSS
            data = read(`$path $pid $duration`, String)
            push!(samples, parsedata(wss, data))
        end
    finally
        return samples
    end
end

