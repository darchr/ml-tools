# Code for invoking the wss.pl dependency.

abstract type WSSTool end

# C tool
struct WSSv2 <: WSSTool end
getpath(::WSSv2) = joinpath(PKGDIR, "deps", "wss-v2")

# PERL tool
struct WSSpl <: WSSTool end
getpath(::WSSpl) = joinpath(PKGDIR, "deps", "wss", "wss.pl" )

"""
    collect(::WSSv2, pid; sleeptime = 0, duration = 10)

Use the `wss=v2` tool to estimate the working set size of `pid` for as long as `pid` is 
active. Returns two equal lenght vectors: the first is the estimated WSS sizes and the 
second is the corresponding approximate time stamps of the measurements.

Keywords
--------
* `sleeptime` - The time to sleep between measurements. Default: `0`
* `duration` - The time overwhich to take a measurement. Default: `10`
"""
function Base.collect(wss::WSSTool, pid; sleeptime = 0, duration = 10)
    # Get the path to the wss-v2 executable
    path = getpath(wss)   

    sizes = Int[] 
    timestamps = DateTime[]

    try
        # Once the process gets killed, wss should exit with a nonzero status. The `read`
        # command will throw an error, at which point we clean up and return the vector
        # of sizes.
        while true
            # Invoke WSS
            data = read(`$path $pid $duration`)
            println(data)
        end
    finally
        return nothing
    end
end

