using Documenter, Launcher

makedocs(
    modules = [Launcher],
    format = :html,
    sitename = "ML-Tools",
    # Make local build look good.
    html_prettyurls = get(ENV, "CI", nothing) == "true",
    linkcheck = get(ENV, "CI", nothing) == "true",
    pages = Any[
        "Home" => "index.md",
        "Manifest" => "manifest.md",
        "Notebooks" => "notebooks.md",
        "Workloads" => [
            "workloads/primary.md",
            "workloads/ubuntu.md",
            "workloads/slim.md",
            "workloads/keras.md",
        ],
        "Datasets" => [
            "datasets/imagenet.md",
            "datasets/rnn.md",
            "datasets/brats.md",
        ]
        "Launcher" => [
            "launcher.md"
        ],
        "NVM" => [
            "nvm/swap.md",
        ],
        "Misc" => [
            "extra/perf.md",
        ],
    ]
)

deploydocs(
    repo = "github.com/darchr/ml-tools",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
