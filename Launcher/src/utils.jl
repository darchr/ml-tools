size_mb(x) = 4 * x / 1024
make_cdf(x::MemSnoop.StackTracker) = MemSnoop.cdf(MemSnoop.transform(x.distances))
memory_vec(x) = size_mb(1:length(x))

save(file::String, x) = open(io -> serialize(io, x), file, write = true) 
load(file::String) = open(deserialize, file)
