# A simple test workload to allow quick debugging
struct TestWorkload <: AbstractWorkload end

image(::TestWorkload) = "darchr/tf-keras:latest"
startfile(::TestWorkload, ::Type{OnHost}) = joinpath(WORKLOADS, "ubuntu", "sleep.sh" )
startfile(::TestWorkload, ::Type{OnContainer}) = joinpath("/home", "startup", "sleep.sh")

runcommand(test::TestWorkload) = `$(startfile(test, OnContainer))`

function create(test::TestWorkload; cpuSets = "", kw...)
    bind_start = join([
        dirname(startfile(test, OnHost)),
        dirname(startfile(test, OnContainer)),
    ], ":")

    @show runcommand(test)
    # Create the container
    container = DockerX.create_container( 
        image(test);
        attachStdin = true,
        binds = [bind_start],
        cmd = runcommand(test),
        cpuSets = cpuSets
    )

    return container
end
