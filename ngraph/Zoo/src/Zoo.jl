module Zoo

using Statistics, Random
using Flux, nGraph

include("models/inception_v4.jl")
include("models/vgg.jl")
include("models/resnet.jl")
include("models/densenet.jl")
include("models/gnmt.jl")
#include("models/rhn.jl")
#include("models/transformer.jl")
#include("models/unet.jl")

# Debug models
include("debug_models/vgg.jl")

end # module
