# A simple test workload to allow quick debugging
"""
Launch the test workload in a `ubuntu` image.

Fields
---

* none

[`create`](@ref) Keyword Arguments
----------------------------------

* none
"""
struct TestWorkload <: AbstractWorkload end
getargs(::TestWorkload) = NamedTuple()

image(::TestWorkload) = "ubuntu:latest"
startfile(::TestWorkload, ::Type{OnHost}) = joinpath(WORKLOADS, "test", "src", "sleep.sh" )
startfile(::TestWorkload, ::Type{OnContainer}) = joinpath("/startup", "sleep.sh")

runcommand(test::TestWorkload) = `$(startfile(test, OnContainer))`

function create(test::TestWorkload; kw...)
    bind_start = join([
        dirname(startfile(test, OnHost)),
        dirname(startfile(test, OnContainer)),
    ], ":")

    # Create the container
    container = Docker.create_container( 
        image(test);
        attachStdin = true,
        binds = [bind_start],
        cmd = runcommand(test),
    )

    return container
end
