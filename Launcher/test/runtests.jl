using Launcher
using Test

@testset "Testing Utilities" begin
    @test Launcher.dash("hello") == "--hello"
    @test Launcher.dash(:hello) == "--hello"

    # Test "makeargs"
    nt = (batchsize = 128, epochs = 2)
    @test Launcher.makeargs(nt) == ["--batchsize", 128, "--epochs", 2]
    nt = (noarg = nothing, batchsize = 128)
    @test Launcher.makeargs(nt) == ["--noarg", "--batchsize", 128]
end
