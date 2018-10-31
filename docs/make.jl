using Documenter, Launcher

makedocs(
    modules = [Launcher],
    format = :html,
    sitename = "ml-tools",
    pages = Any[
        "index.md", 
        "notebooks.md",
        "Docker" => Any[
            "docker.md",
            "tensorflow.md",
        ],
        "Workloads" => Any[
            "ubuntu.md",
            "keras.md",
        ],
        "Launcher" => Any[
            "launcher.md"
        ]
    ]
)

deploydocs(
    repo = "github.com/darchr/ml-tools",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
