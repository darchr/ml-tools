using Documenter, Launcher

makedocs(
    modules = [Launcher],
    format = :html,
    sitename = "ml-tools",
    pages = Any[
        "index.md", 
        "notebooks.md",
        "Tensorflow" => Any[
           "tensorflow.md",
           "tf-compiled-base.md"
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
