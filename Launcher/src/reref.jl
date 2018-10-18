# Tools for computing the rereference intervals of memory blocks. Based on WSS:
#
# http://www.brendangregg.com/wss.pl
#

struct Page 
    address :: UInt64
end

Base.parse(::Type{Page}, x) = Page(parse(UInt, x; base = 16))

struct SmapsSample
    timestamp :: DateTime
    pages :: Dict{Page, Int}
end

function clear_ref(pid)
    open("/proc/$pid/clear_refs", "w") do clr
        write(clr, '1')
    end
end

function sample(pid, sleeptime = 0.1)
    # Clear the reference bits
    clear_ref(pid) 
    # Sleep for the specified time
    sleep(sleeptime) 
    return IOBuffer(read("/proc/$pid/smaps")), now()
end

islowerhex(c::AbstractChar) = '0'<=c<='9' || 'a'<=c<='f'

# TODO: move timestamp out of this function ... 
"""
    getpages(smaps) -> SmapeSample

Return a collection of pages referenced in a `smaps` trace as a dict mapping page to the
number of `kB` of memory of that page that was referenced.
"""
function getpages(smaps)
    referenced_pages = Dict{Page,Int}()
    page = UInt(0)

    # Iterate over lines
    for ln in eachline(smaps)
        # Address references begin with hex digits, and should be the only items beginning
        # with hex digits in the trace.
        if islowerhex(first(ln))
            # Create a substring for the first hex, parse it into an integer
            base_address = SubString(ln, 1, findfirst(isequal('-'), ln) - 1)
            page = parse(Page, base_address)

        # Parse the size of the page table.

        # If this is the "Referenced" page, check to see if the values is non-zero
        #
        # We expect the line to look like this;
        #
        # Referenced:            4 kB
        # 
        # Where the 4 kB indicates that this page was referenced since we last clear the
        # reference flags. If this page was not referenced, this value would be 0
        elseif startswith(ln, "Ref")
            size_referenced = split(ln)[2]
            # If this page was referenced, push this address onto the set of seen addresses.
            if size_referenced != "0"
                # Parse the amount of memory referenced and save this sample
                referenced_pages[page] = parse(Int, size_referenced)
            end
        end
    end
    return referenced_pages
end


function monitor(pid::Int; sleeptime = 1.0)
    local samples = SmapsSample[] 
    while true
        try
            buffer, timestamp = sample(pid, sleeptime) 
            referenced_pages = getpages(buffer)
            this_sample = Page(timestamp, referenced_pages)
            push!(samples, this_sample)
        catch err
            @error err
            return samples
        end
    end
end

############################################################################################
# Older functions

# increment!(d::AbstractDict, k, v) = haskey(d, k) ? (d[k] += v) : (d[k] = v)
# 
# 
# function cleantrailing!(bucketstack)
#     while !isempty(bucketstack) && (isempty ∘ last)(bucketstack)
#         pop!(bucketstack)
#     end
#     return nothing
# end
# 
# 
# function rereference!(distribution::AbstractDict, bucketstack, items)
#     for (depth, bucket) in enumerate(bucketstack)
#         # Get the indices of items in this bucket that are in the list of items to look
#         # for.
#         inds = findall(x -> in(x, items), bucket)
#         if !isempty(inds)
#             increment!(distribution, depth, length(inds))
#         end
#         # Remove the matching items from the bucket.
#         deleteat!(bucket, inds)
#     end
# 
#     # Add the new items to the front of the bucketstack
#     pushfirst!(bucketstack, items)
# 
#     # Do some cleanup
#     cleantrailing!(bucketstack)
# end


# function monitor_reref(pid; sleeptime = 1.0)
#     distribution = Dict{Int, Int}()
#     bucketstack = Vector{Vector{UInt}}()
# 
#     while true
#         local addresses
#         try
#             addresses = sample(pid, sleeptime) |> parse_smaps
#         catch
#             return distribution
#         end
#         rereference!(distribution, bucketstack, addresses)
#     end
# end 
