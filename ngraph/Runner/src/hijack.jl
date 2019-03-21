# Create a wrapper for the general Optimizers defined in nGraph.jl to swap in and out
# various inputs and outputs from DRAM and PMEM.

struct Hijack{T}
    x::T
end
hijack(x) = Hijack(x)

struct HijackOptimizer{T, I <: nGraph.Tensor, O <: nGraph.Tensor}
    optimizer::T
    # Shadows the input and outputs of `optimizer`, but resides in persistent memory.
    persistent_inputs::Vector{I}
    persistent_outputs::Vector{O}

    # Masks for determining which persistent parameters to swap in or out.
    input_masks::BitVector
    output_masks::BitVector
end

# Extend the `create` API for optimizers
function nGraph.create(H::Hijack, args...; kw...)
    opt, opt_inputs, opt_outputs = nGraph.create(H.x, args...; kw...)

    backend = nGraph.Backend()

    persistent_inputs = nGraph.PersistentTensor.(Ref(backend), opt_inputs, true)
    persistent_outputs = nGraph.PersistentTensor.(Ref(backend), opt_outputs, false)

    input_masks = falses(length(persistent_inputs))
    output_masks = falses(length(persistent_outputs))

    hijack_optimizer = HijackOptimizer(
        opt,
        persistent_inputs,
        persistent_outputs,
        input_masks,
        output_masks,
    )

    return hijack_optimizer, opt_inputs, opt_outputs
end

# Extend the rest of the API
nGraph.update!(::HijackOptimizer) = nothing

nGraph.getinputs(H::HijackOptimizer) = (
    H.input_masks[i] ? H.persistent_inputs[i] : t
    for (i,t) in enumerate(nGraph.getinputs(H.optimizer))
)

nGraph.getoutputs(H::HijackOptimizer) = (
    H.output_masks[i] ? H.persistent_outputs[i] : t
    for (i,t) in enumerate(nGraph.getoutputs(H.optimizer))
)
