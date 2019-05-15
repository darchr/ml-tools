using Documenter, Mop

makedocs(
    modules = [Mop],
    format = :html,
    checkdocs = :exports,
    sitename = "Mop.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "github.com/hildebrandmw/Mop.jl.git",
)
