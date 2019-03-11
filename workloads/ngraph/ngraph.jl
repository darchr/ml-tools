using ArgParse, Statistics, Metalhead, nGraph

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--model"
            help = "Define the model to use"
            arg_type = String
            default = "resnet50"

        "--batchsize"
            help = "The Batchsize to use"
            arg_type = Int
            default = 16

        "--mode"
            help = "The mode to use [train or inference]"
            arg_type = String
            default = "inference"

        # "--pmem"
        #     help = "Perform all allocations to PMEM"
        #     action = :store_true

        # "--pmempool"
        #     help = """
        #     The name of the persistent memory pool to use. Only valid of the `--pmem` flag
        #     is provided"""
        #     arg_type = String
        #     default = "/mnt/file.pmem"

        "--iterations"
            help = "The number of calls to perform for benchmarking"
            arg_type = Int
            default = 20
    end

    return parse_args(s)
end

function getmodel(opt::String, mode::String, batchsize)
    if opt == "resnet50"
        if mode == "inference"
            @info "Mode: Inference"

            # Get the model from Metalhead.
            resnet = Metalhead.resnet_layers() 
            backend = nGraph.Backend()
            X = nGraph.Tensor(backend, rand(Float32, 224, 224, 3, batchsize))
            f = nGraph.compile(backend, resnet, X)

            return f, (X,)
        end
    end

    error("Something went wrong")
end

# function setup_pool(pool)
#     manager = nGraph.Lib.getinstance()
#     nGraph.Lib.enablepmem(manager)
#     nGraph.Lib.setpool(manager, pool)
#     ispath(pool) && rm(pool)
#     nGraph.Lib.createpool(manager, UInt(2)^38)
#     #nGraph.Lib.openpool(manager)
#     return nothing
# end

function main()
    parsed_args = parse_commandline()

    # Unpack some arguments
    batchsize = parsed_args["batchsize"] 
    iterations = parsed_args["iterations"]

    # Get model
    f, args = getmodel(parsed_args["model"], parsed_args["mode"], batchsize)

    # Warm up calls
    @info "Warming Up"
    for _ in 1:3
        f(args...)
    end

    # Testing Calls
    @info "Running" 
    time = @elapsed for _ in 1:iterations
        f(args...)
    end

    # Compute the average number of images per second.
    images_per_second = batchsize * iterations / time
    time_per_iteration = time / iterations

    println("Images Per Second: [$images_per_second]")
    println("Time per iteration: [$time_per_iteration]")
end

main()
