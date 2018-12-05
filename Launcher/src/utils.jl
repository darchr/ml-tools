bind(a, b) = join((a, b), ":")

size_mb(x) = 4 * x / 1024
subsample(x, n) = x[1:n:end]
#make_cdf(x::MemSnoop.DistanceTracke)  MemSnoop.cdf(MemSnoop.transform(x.distances))

memory_vec(x) = size_mb(1:length(x))

save(file::String, x) = open(io -> serialize(io, x), file, write = true) 
load(file::String) = open(deserialize, file)

uid() = chomp(read(`id -u`, String))
