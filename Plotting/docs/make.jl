using Documenter, Plotting

makedocs(
    modules = [Plotting],
    format = :html,
    sitename = "Plotting.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "github.com/hildebrandmw/Plotting.jl.git",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
