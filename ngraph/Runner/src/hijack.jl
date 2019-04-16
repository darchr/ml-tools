# Create a wrapper for the general Optimizers defined in nGraph.jl to swap in and out
# various inputs and outputs from DRAM and PMEM.

struct Hijack{U,T}
    update::U
    x::T
end

# Allow the hijacked optimizer to opt ouf of updating for verification purposes.
struct WithUpdate end
struct WithoutUpdate end

hijack(u::U, x::T) where {U <: Union{WithUpdate,WithoutUpdate}, T} = Hijack(u, x)
hijack(x::T) where {T} = hijack(WithUpdate(), x)

"""
Wrapper around a generic nGraph.jl optimizer that allows arbitrary input and output
tensors to be placed in DRAM or PMEM.

Fields
------

* `optimizer::T` - The actual optimizer that is being wrapped. In the optimizer, all
    of the tensors live in DRAM.

* `persistent_inputs::Vector` - Persistent Memory clones of the input tensor in 
    `optimizer`. These will be substituted in for the DRAM tensor from `optimizer` if
    the corresponding index in the `input_masks` field is `true`.

* `persistent_outputs::Vector` - Persistent Memory clones of the output tensor in 
    `optimizer`. These will be substituted in for the DRAM tensor from `optimizer` if
    the corresponding index in the `output_masks` field is `true`.

* `input_masks::BitVector` - Mask of which input tensors should be in persistent 
    memory. A `true` value implies PMEM, while `false` implies DRAM.

* `output_masks::BitVector` - Mask of which output tensors should be in persistent 
    memory. A `true` value implies PMEM, while `false` implies DRAM.
"""
struct HijackOptimizer{U, T, I <: nGraph.Tensor, O <: nGraph.Tensor}
    update::U
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
        H.update,
        opt,
        persistent_inputs,
        persistent_outputs,
        input_masks,
        output_masks,
    )

    return hijack_optimizer, opt_inputs, opt_outputs
end

# Extend the rest of the API
nGraph.update!(H::HijackOptimizer{WithoutUpdate}) = nothing
nGraph.update!(H::HijackOptimizer) = nGraph.update!(H.optimizer)

nGraph.getinputs(H::HijackOptimizer) = (
    H.input_masks[i] ? H.persistent_inputs[i] : t
    for (i,t) in enumerate(nGraph.getinputs(H.optimizer))
)

nGraph.getoutputs(H::HijackOptimizer) = (
    H.output_masks[i] ? H.persistent_outputs[i] : t
    for (i,t) in enumerate(nGraph.getoutputs(H.optimizer))
)
