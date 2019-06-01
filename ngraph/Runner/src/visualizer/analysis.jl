"""
    * counts - Dictionary to modify.
    * node::NodeWrapper - Node to check.
    * prefix::String - String to prefix to the i/o number. Result will look somethjing
        like "ConvolutionBias_\$(prefix)_0" etc.
    * fn - Function to call on NodeWrapper to generate inputs or outputs. Should be one
        of `inputs` or `outputs`.
"""
function _count!(counts, node::NodeWrapper, prefix::String, fn)
    for (index, tensor) in enumerate(fn(node))
        name = join((description(node), prefix, index), "_")
        data = get!(counts, name, Dict(:pmem => 0, :dram => 0))
        if is_persistent(tensor) 
            data[:pmem] += 1
        else
            data[:dram] += 1
        end
    end
end

function kernel_io_count(fex::nGraph.FluxExecutable)
    fn = fex.ex.ngraph_function

    counts = OrderedDict{String, Dict{Symbol, Int}}()
    for unwrapped_node in fn
        node = NodeWrapper(unwrapped_node)
        _count!(counts, node, "input", inputs)
        _count!(counts, node, "output", outputs)
    end
    return counts
end
