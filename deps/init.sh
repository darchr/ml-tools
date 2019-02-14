#!/bin/bash

JULIA_CMD=${1:-julia}

# Fetch git repos
git clone https://github.com/hildebrandmw/Docker.jl Docker

$JULIA_CMD --project=. -e "using Pkg; Pkg.build()"
