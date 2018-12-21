@testset "Testing Basic Workloads" begin
    #####
    ##### Dummy workload
    #####

    workload = Launcher.TestWorkload()
    run(workload)

    #####
    ##### CifarCnn
    #####

    # Just pass the help argument to the routine. Should print out help and then exit -
    # no need for the dataset.
    #
    # Will catch any path errors during setup.
    #
    # First need to setup a dummy path to the dataset.
    Launcher.DATASET_PATHS["cifar"] = pwd()
    cnn = CifarCnn(args = (help = nothing,))
    run(cnn)

    #####
    ##### Tensorflow Resnet
    #####

    # Create a couple of directories that the script is looking for
    if !isdir("train") 
        remove_train = true
        mkdir("train")
    else
        remove_train = false
    end

    if !isdir("validation") 
        remove_validation = true
        mkdir("validation")
    else
        remove_validation = false
    end

    Launcher.DATASET_PATHS["imagenet_tf_official"] = pwd()
    cnn = Launcher.ResnetTF(args = (help = nothing,))
    run(cnn)

    remove_train && rm("train")
    remove_validation && rm("validation")
end
