# Tools for computing the rereference intervals of memory blocks. Based on WSS:
#
# http://www.brendangregg.com/wss.pl

#using RecipesBase
using Makie

struct Page 
    address :: UInt64
end
getaddress(p::Page) = p.address
Base.parse(::Type{Page}, s::AbstractString) = Page(parse(UInt, s; base = 16))
Base.isless(a::Page, b::Page) = isless(a.address, b.address)


struct Sample
    mmap :: Dict{Page, Int}
end
pages(s::Sample) = keys(s.mmap)
Base.getindex(s::Sample, p::Page) = get(s.mmap, p, zero(valtype(s.mmap)))


struct Trace
    samples::Dict{DateTime,Sample}
end
Trace() = Trace(Dict{DateTime,Sample}())

Base.iterate(T::Trace, args...) = iterate(T.samples, args...)
samples(T::Trace) = values(T.samples)
times(T::Trace) = keys(T.samples)
Base.setindex!(T::Trace, sample, time::DateTime) = T.samples[time] = sample
Base.getindex(T::Trace, time::DateTime) = T.samples[time]

function allpages(T::Trace)
    pageset = Set{Page}()
    for sample in samples(T)
        # Use broadcasting to do this tersly. Wrap "pages" in a Ref because we want it
        # to behave as a scalar for broadcasting.
        push!.(Ref(pageset), pages(sample))
    end
    return (sort ∘ collect)(pageset)
end


# Proc accessors
function clear_ref(pid)
    open("/proc/$pid/clear_refs", "w") do clr
        write(clr, '1')
    end
end

read_smaps(pid) = (IOBuffer ∘ read)("/proc/$pid/smaps")

# Helper Functions
islowerhex(c::AbstractChar) = '0'<=c<='9' || 'a'<=c<='f'

"""
    parse(::Type{Sample}, buffer::IO) -> Sample

Return a collection of pages referenced in a `buffer` trace as a dict mapping page to the
number of `kB` of memory of that page that was referenced.
"""
function Base.parse(::Type{Sample}, buffer::IO)
    mmap = Dict{Page,Int}()
    page = UInt(0)

    # Iterate over lines
    for ln in eachline(buffer)
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
            size = split(ln)[2]
            # If this page was referenced, push this address onto the set of seen addresses.
            if size != "0"
                # Parse the amount of memory referenced and save this sample
                mmap[page] = parse(Int, size)
            end
        end
    end
    return Sample(mmap)
end


function monitor(pid::Int; sampletime = 1.0)
    local trace = Trace()
    try
        # Run until process dies - not great :(
        while true
            clear_ref(pid)

            # Sleep, then sample
            pause(sampletime)
            buffer = read_smaps(pid) 

            # Parse and save result
            trace[timestamp] = parse(Sample, buffer)
        end
    catch err
        @error err
        return trace
    end
end

## Plotting

function plot(trace::Trace)
    pages = allpages(trace)
    timestamps = times(trace)

    references = [trace[timestamp][page] for page in pages, timestamp in timestamps]

    z = clamp.(log2.(references), 0, Inf)
    return heatmap(z)
end

# @recipe function f(trace::Trace)
#     # Get all the pages and timestamps seen in this trace
#     pages = allpages(trace)
#     timestamps = times(trace)
# 
#     references = [trace[timestamp][page] for page in pages, timestamp in timestamps]
# 
#     size := (1000, 1000)
#     # Create the plot
#     @series begin 
#         seriestype := :heatmap
#         x = 1:length(pages)
#         y = 1:length(timestamps)
#         x, y, clamp.(log2.(references), 0, Inf)
#     end
# end
