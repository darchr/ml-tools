# We need to be able to verify that the output of modified graphs matches that of a standard
# graph.
#
# To do that, we use an auxiliary function that accepts the constructor function for a model
# as well as any passes to be performed on the model and checks that the base computation 
# matches the modifed computation.
#
# NOTES:
# - Need to set the random seed before each call to the model constructor to ensure that
#   the model enters a known and consistent state before any modification.
#
# - Need to provide utility functions to extract the before/after parameters of each 
#   function for comparison.
astuple(x::Tuple) = x
astuple(x) = (x,)

"""
- `f`: Function `() -> fex, args` that constructs a model and its arguments.

- `pass`: Function `(FluxExecutable) -> FluxExecutable`: Takes an executable and returns
    a modified executable that will be compared against the baseline executable.
"""
function verify(f, pass; seed = 8086)
    # Set the random seed and compile the initial function
    Random.seed!(seed)
    fex, args = f()
    
    # Call the function once. Wrap the results in a tuple so we can iterate over it 
    # generically.
    #
    # TODO: Maybe add a `params` argument to nGraph.jl to make this a little cleaner.
    results = astuple(fex())
    inputs = nGraph.getinputs(fex.optimizer)
    outputs = nGraph.getoutputs(fex.optimizer)

    # Check results for NaNs
    @assert !any(x -> any(isnan, read(x)), results)
    @assert !any(x -> any(isnan, read(x)), inputs)
    @assert !any(x -> any(isnan, read(x)), outputs)


    # Now that we have baseline results, we compile again and then run the pass on the
    # results.
    Random.seed!(seed)    
    fex_p, args_p = f()
    fex_p = pass(fex_p)

    results_p = astuple(fex_p())
    inputs_p = nGraph.getinputs(fex.optimizer)
    outputs_p = nGraph.getoutputs(fex.optimizer)

    @assert !any(x -> any(isnan, read(x)), results_p)
    @assert !any(x -> any(isnan, read(x)), inputs_p)
    @assert !any(x -> any(isnan, read(x)), outputs_p)

    # util function
    g = (a,b) -> all(isapprox.(read.(a), read.(b)))
    args_match    = g(args_p, args)
    results_match = g(results_p, results)
    inputs_match  = g(inputs_p, inputs)
    outputs_match = g(outputs_p, outputs)

    return args_match, results_match, inputs_match, outputs_match
end
