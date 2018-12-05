# Test the build scripts for derived docker images.
@testset "Testing Derived Docker Builds" begin
    # For returning to after each test
    wd = pwd()

    #####
    ##### darchr/tf-keras
    #####
    
    @info "Building `tf-keras`"
    script_path = joinpath(DOCKER, "tensorflow", "tf-keras")
    script_name = "build.sh"
    cd(script_path)
    try
        str = read(`./$script_name`, String)
        println(str)
    finally
        cd(wd)
    end

    #####
    ##### darchr/tf-official-models
    #####
    
    @info "Building `tf-official-models`"
    script_path = joinpath(DOCKER, "tensorflow", "tf-official-models")
    script_name = "build.sh"
    cd(script_path)
    try
        str = read(`./$script_name`, String)
        println(str)
    finally
        cd(wd)
    end
end
