using Runner
using Test
using Serialization
using Zoo

# @testset "Testing Simple Formulation" begin
#     f = () -> Runner.simple_network()
#     pass = function _dummy(fex)
#         data = Runner.profile(fex)
# 
#         bounds = Runner.allocation_bounds(data)
#         x = round(Int, bounds.upper_bound / (1E6 * 2))
#         S = Runner.Simple(x) 
#         frame = Runner.create_model(S, data)
#         Runner.optimize!(frame)
#         fex = Runner.configure!(fex, frame)
#         return fex 
#     end
# 
#     matches = Runner.verify(f, pass)
#     @show matches
#     @test all(matches)
# 
#     f = () -> Zoo.vgg19_training(128) 
#     matches = Runner.verify(f, pass)
#     @show matches
#     @test all(matches)
# 
#     f = () -> Zoo.inception_v4_training(128)
#     matches = Runner.verify(f, pass)
#     @show matches
#     @test all(matches)
# end

@testset "Testing Synchronous Formulation" begin
    f = () -> Runner.simple_network()
    pass = function _dummy(fex)
        data = Runner.profile(fex)
        bounds = Runner.allocation_bounds(data)
        x = round(Int, bounds.upper_bound / (1E6 * 10))
        S = Runner.Synchronous(x, 29000, 12000) 
        frame = Runner.create_model(S, data)
        Runner.optimize!(frame)
        fex, _ = Runner.configure!(fex, frame)
        return fex 
    end

    matches = Runner.verify(f, pass)
    @show matches
    @test all(matches)

   f = () -> Zoo.vgg19_training(128) 
   matches = Runner.verify(f, pass)
   @show matches
   @test all(matches)
 
   f = () -> Zoo.inception_v4_training(128)
   matches = Runner.verify(f, pass)
   @show matches
   @test all(matches)
end
