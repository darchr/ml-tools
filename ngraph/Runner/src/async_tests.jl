# Tests for the kind-of wonky asynchronous move node
function test_conv_async(return_early = false)
    # Add two nodes, pass a third one across
    f(a,b,c,d) = (Conv(a, b, relu; pad = 1)(c), d) 

    backend = nGraph.Backend()

    a = rand(Float32, 3, 3, 512, 512)
    b = rand(Float32, 512)
    c = rand(Float32, 112, 112, 512, 64)
    d = rand(Float32, 100)

    A = nGraph.Tensor(backend, a)
    B = nGraph.Tensor(backend, b)
    C = nGraph.Tensor(backend, c)
    D = nGraph.Tensor(backend, d)

    fex = nGraph.compile(f, A, B, C, D)

    return_early && return fex

    # Post graph mutation - find the tensor belonging to the input and move it across the
    # add node
    # for op in fex.ex.ngraph_function 
    #     @show nGraph.description(op)
    # end

    # Step 1: Find the add node
    local add_node
    found = false
    for op in fex.ex.ngraph_function
        if nGraph.description(op) == "ConvolutionBias"
            add_node = op
            found = true
            println("Found!")
            break
        end
    end
    @assert found

    # Step 2: Find the input parameter - it will be the one whose output is a result
    local target_input
    local target_output
    found = false
    for param in nGraph.get_parameters(fex.ex.ngraph_function)
        println(nGraph.name(param))
        for output_vector in nGraph.get_outputs(param), output in output_vector
            println(nGraph.name(output))
            if isresult(output)
                target_input = param
                target_output = output
                found = true
                println("Found!")
                break
            end
        end
        found && break
    end
    @assert found

    # Just splice a move node for now
    nGraph.splice(
        target_input,  1, 
        target_output, 1, 
        nGraph.moveasync(target_input, add_node)
    )

    fex = nGraph.recompile(fex)

    return fex
end

function test_conv_add(return_early = false)
    # Add two nodes, pass a third one across
    f(a,b,d) = (a + b,  d) 

    backend = nGraph.Backend()

    a = rand(Float32, 1000, 1000)
    b = rand(Float32, 1000, 1000)
    c = rand(Float32, 100)

    A = nGraph.Tensor(backend, a)
    B = nGraph.Tensor(backend, b)
    C = nGraph.Tensor(backend, c)

    fex = nGraph.compile(f, A, B, C)

    return_early && return fex

    # Post graph mutation - find the tensor belonging to the input and move it across the
    # add node
    # for op in fex.ex.ngraph_function 
    #     @show nGraph.description(op)
    # end

    # Step 1: Find the add node
    local add_node
    found = false
    for op in fex.ex.ngraph_function
        if nGraph.description(op) == "Add"
            add_node = op
            found = true
            println("Found!")
            break
        end
    end
    @assert found

    # Step 2: Find the input parameter - it will be the one whose output is a result
    local target_input
    local target_output
    found = false
    for param in nGraph.get_parameters(fex.ex.ngraph_function)
        println(nGraph.name(param))
        for output_vector in nGraph.get_outputs(param), output in output_vector
            println(nGraph.name(output))
            if isresult(output)
                target_input = param
                target_output = output
                found = true
                println("Found!")
                break
            end
        end
        found && break
    end
    @assert found

    # Just splice a move node for now
    nGraph.splice(
        target_input,  1, 
        target_output, 1, 
        nGraph.moveasync(target_input, add_node)
    )

    fex = nGraph.recompile(fex)

    return fex
end
