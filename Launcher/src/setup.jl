setupexists() = ispath(SETUP_PATH)

const DATASETS = (
    "cifar", 
    "imagenet_tf_slim",
    "rnn_translator",
    "brats",
)

_writedataset() = open(io -> JSON.print(io, DATASET_PATHS, 4), SETUP_PATH, "w")

function setup()
    if !setupexists()
        @warn """
        File "setup.json" describing the paths to datasets does not exist in directory 
        "Launcher". Creating a skeleton file. Edit this file with the paths to the relevant
        datasets.

        This file can be edited by calling:

        ```
        Launcher.edit_setup()
        ```
        """
        _writedataset()
    end

    json = JSON.parsefile(SETUP_PATH)

    empty!(DATASET_PATHS)
    for dataset in DATASETS
        DATASET_PATHS[dataset] = get(json, dataset, "")
    end
    # If things change, writing the dataset here will reflect those changes.
    _writedataset()
    return nothing
end


edit_setup() = (InteractiveUtils.edit(SETUP_PATH); setup())
