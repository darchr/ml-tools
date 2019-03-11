# Environmental Variables:
#
# NGRAPH_CODEGEN=1
# NGRAPH_PASS_ATTRIBUTES="MemoryAssignment::ReuseMemory=1"
@with_kw struct NGraph <: AbstractWorkload
    args::NamedTuple = NamedTuple()
end

_srcdir(::NGraph, ::Type{OnHost}) = joinpath("$WORKLOADS", "ngraph")
_srcdir(::NGraph, ::Type{OnContainer}) = "/ngraph"

startfile(N::NGraph) = joinpath(_srcdir(N, OnContainer), "ngraph.jl")

function runcommand(model::NGraph)
    kw = model.args

    @default kw model "resnet50"
    @default kw mode "inference"

    return `julia $(startfile(model)) $(makeargs(kw))`
end

function create(model::NGraph; kw...)
    # Bind PMEM files
    bind_code = bind(_srcdir(model, OnHost), _srcdir(model, OnContainer))

    @show runcommand(model)

    container = create_container(
        NGraphImage(),
        binds = [bind_code],
        cmd = runcommand(model),
        env = [
            "NGRAPH_CODEGEN=1",
        ]
    )
end
