@testset "Testing Utility Functions" begin
    @test Launcher.isnothing(10) == false
    @test Launcher.isnothing(nothing) == true

    @test Launcher.bind("hello", "world") == "hello:world"
    # Just call uid, makesure nothing bad happens
    Launcher.uid()

    @test Launcher.dash("hello") == "--hello"
    @test Launcher.dash(:hello) == "--hello"

    #####
    ##### Argument formatting
    #####

    @test Launcher.argify(:with_coffee, nothing, "=") == "--with_coffee"
    @test Launcher.argify(:batchsize, 192, "=") == "--batchsize=192"

    @test Launcher.argify(:with_coffee, nothing) == ("--with_coffee",)
    @test Launcher.argify(:batchsize, 192) == ("--batchsize", 192)

    args = (dataset_dir = "/imagenet", batchsize = 192, with_coffee = nothing)

    @test Launcher.makeargs(args, "=") == [
        "--dataset_dir=/imagenet",
        "--batchsize=192",
        "--with_coffee"
    ]

    @test Launcher.makeargs(args) == [
        "--dataset_dir", "/imagenet",
        "--batchsize", 192,
        "--with_coffee"
    ]
end
