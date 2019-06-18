# Test the allocator for modnn
@testset "Testing Allocator" begin
    # Instantiate a memory allocator with a memory limit of 100 and alignment of 10
    M = Runner.MemoryAllocator(100, 10)
    node_list = M.node_list
    @test length(node_list) == 1

    # Allocate a block of size 1. We expect it to be located at the beginning of the
    # block.
    offset = Runner.allocate(M, 1) 
    @test offset == 0
    @test length(node_list) == 2

    # The first block should have size 10 due to alignment
    @test Runner.isfree(node_list[1]) == false
    @test sizeof(node_list[1]) == 10
    @test Runner.isfree(node_list[2]) == true
    @test sizeof(node_list[2]) == 90

    # Try freeing this block - make sure we get just a single block back
    Runner.free(M, offset) 

    @test length(node_list) == 1
    @test Runner.isfree(node_list[1]) == true
    @test sizeof(node_list[1]) == 100

    # Allocate three blocks - free the middle one, then free the last
    a = Runner.allocate(M, 11) 
    b = Runner.allocate(M, 9)
    c = Runner.allocate(M, 20)

    @test a == 0
    @test b == 20
    @test c == 30
    @test length(node_list) == 4
    @test Runner.isfree(node_list[1]) == false
    @test Runner.isfree(node_list[2]) == false
    @test Runner.isfree(node_list[3]) == false
    @test Runner.isfree(node_list[4]) == true
    @test sizeof(node_list[1]) == 20
    @test sizeof(node_list[2]) == 10
    @test sizeof(node_list[3]) == 20
    @test sizeof(node_list[4]) == 50

    Runner.free(M, b)
    @test length(node_list) == 4
    @test Runner.isfree(node_list[1]) == false
    @test Runner.isfree(node_list[2]) == true
    @test Runner.isfree(node_list[3]) == false
    @test Runner.isfree(node_list[4]) == true
    @test sizeof(node_list[1]) == 20
    @test sizeof(node_list[2]) == 10
    @test sizeof(node_list[3]) == 20
    @test sizeof(node_list[4]) == 50

    Runner.free(M, c)
    @test length(node_list) == 2
    @test Runner.isfree(node_list[1]) == false
    @test Runner.isfree(node_list[2]) == true
    @test sizeof(node_list[1]) == 20
    @test sizeof(node_list[2]) == 80

    # Test that an oversized allocation fails
    @test isnothing(Runner.allocate(M, 200)) 
end
