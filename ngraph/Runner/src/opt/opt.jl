# Sub project for taking a set of profiled data and building a JuMP model forming some
# optimization problem over that data.
#
# The main initial goal is to
# - Minimize the sum of kernel execution times
# - By assigning the locations of live intermediate tensors to either DRAM or PMEM
# - With a fixed memory budget of live tensors in DRAM
#
# However, we would like the framework to be flexible enough to allow swapping in of
# different:
#
# - Models for kernel execution times
# - High level problem descriptions
# - Retain the ability to insert "move" nodes and perform more complicated passes.
#
# #####
# ##### Initial Setup
# #####
#
# For just the initial formulation, we need the following pipeline:
#
# - Base data structure will be a vector of nGraph ops in `ordered_ops` structure,
#   which is the order that they are executed by the nGraph runtime.
#
# - Get a list of all intermediate tensors and sizes.
#   Each tensor can either live in DRAM or PMEM, so we need to generate JuMP variables
#   accordingly.
#
# - Do a liveness analysis to determine where tensors begin and when they go out of
#   scope.
#
# - Iterate through each op in the nGraph ops. For each op, generate
#
#   1. A capacity constraint on the number of live tensors in DRAM.
#   2. Generate a `gadget` to encode the running time of the kernel given the locations
#      of its inputs and outputs.
#   3. Add the results of this gadget to the global objective function, which will be
#      to minimize the sum of active running times.
#
# To accomplish this, we need to pass around a JuMP `Model` which we may progressively
# add variables and constraints to.
#
# To sequentially build the objective function, we can have a JuMP `expression`
# (http://www.juliaopt.org/JuMP.jl/v0.19.0/expressions/) which we update with the
# `add_to_expression!` function at each node in the graph.
using JuMP, Gurobi

# For dispatch purposes
abstract type ModelType end

include("util.jl")
include("simple.jl")
include("sync.jl")
