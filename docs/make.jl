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
        "Docker" => [
            "docker/docker.md",
            "docker/tensorflow.md",
        ],
        "Datasets" => [
            "datasets/imagenet.md",
        ],
        "Workloads" => [
            "workloads/ubuntu.md",
            "workloads/tensorflow.md",
            "workloads/slim.md",
            "workloads/keras.md",
        ],
        "Launcher" => [
            "launcher.md"
        ],
        "NVM" => [
            "nvm/swap.md",
        ],
        "Misc" => [
            "extra/perf.md",
        ],
        "deprecated.md",
    ]
)

deploydocs(
    repo = "github.com/darchr/ml-tools",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
