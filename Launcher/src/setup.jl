setupexists() = ispath(SETUP_PATH)

const DATASETS = ("cifar", "imagenet")

function setup()
    if !setupexists()
        @error """
        File "setup.json" describing the paths to datasets does not exist. Run 
        "create_setup()" to make this file.
        """
        return nothing
    end

    json = JSON.parsefile(SETUP_PATH)

    empty!(DATASET_PATHS)
    for dataset in DATASETS
        DATASET_PATHS[dataset] = json[dataset]
    end
    return nothing
end

function create_setup()
    empty!(DATASET_PATHS)
    for dataset in DATASETS
        print(stdout, "Enter path for dataset \"$dataset\": ")

        # Read back the response and set it up
        path = readline(stdin)
        DATASET_PATHS[dataset] = expanduser(path)
    end

    # Save result so it will be available to load next time.
    open(io -> JSON.print(io, DATASET_PATHS, 4), SETUP_PATH, "w")
    return nothing
end
