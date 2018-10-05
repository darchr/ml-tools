using Documenter, Launcher

makedocs(
    modules = [Launcher],
    format = :html,
    sitename = "Launcher.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "github.com/hildebrandmw/Launcher.jl.git",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
