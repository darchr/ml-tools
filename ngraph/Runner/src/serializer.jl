# Test suite to check if node ordering is consistent across serializations
function serialize_test(fex::nGraph.FluxExecutable, args, file::String)
    fex = nGraph.recompile(nGraph.Backend(), fex, nGraph.deserialize_function(file))
    original_ops = nGraph.description.(fex.ex.ngraph_function)

    fex = nGraph.recompile(nGraph.Backend(), fex, nGraph.deserialize_function(file))
    new_ops = nGraph.description.(fex.ex.ngraph_function)

    @show length(original_ops)
    @show length(new_ops)

    for (i, (a, b)) in enumerate(zip(original_ops, new_ops))
        if a != b
            println("Op Mismatch at: $i")
            println("  Original Op: $a")
            println("  New Op: $b")
            println()
        end
    end


    return all(new_ops .== original_ops)
end
