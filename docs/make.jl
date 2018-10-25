using Documenter, Launcher

makedocs(
    modules = [Launcher],
    format = :html,
    sitename = "Launcher.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "github.com/darchr/ml-tools",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
