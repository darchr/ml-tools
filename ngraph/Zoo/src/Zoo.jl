module Zoo

using Statistics
using Flux, nGraph

include("models/inception_v4.jl")
include("models/vgg.jl")
include("models/resnet.jl")
include("models/densenet.jl")
include("models/rhn.jl")
#include("models/unet.jl")

end # module
