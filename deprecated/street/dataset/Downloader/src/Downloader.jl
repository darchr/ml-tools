module Downloader

using Distributed
import Base.Iterators: partition

function geturls()
    local items
    open(joinpath(@__DIR__, "fsns_url.txt")) do f
        # Operate over two lines at a time
        items = map(partition(eachline(f), 2)) do lines
            url = lines[1]
            # Split the output string
            str = lines[2] 
            range = findfirst("fsns/", str)
            relpath = str[last(range)+1:end]
            path = joinpath(pwd(), relpath)
            return (url = url, path = path)
        end
    end
    return items
end

function _download(item) 
    mkpath(dirname(item.path))
    download(item.url, item.path)
end

function downloadall()
    # Filter out all of the items that already have local paths
    items = filter(x -> !ispath(x.path), geturls())
    pmap(_download, items)
end

end
