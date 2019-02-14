#!/bin/bash

# If a path to the julia executable is given, use that. Otherwise, fall back to just the
# "julia" command
JULIA_CMD=${1:-julia}

# Initialize dependencies
cd deps
source init.sh $JULIA_CMD
cd ..

# Initialize Launcher
$JULIA_CMD --project=Launcher -e "using Pkg; Pkg.instantiate()"
