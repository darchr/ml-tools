#!/bin/bash

# Fetch git repos
git clone https://github.com/hildebrandmw/PAPI.jl PAPI
git clone https://github.com/hildebrandmw/DockerX.jl DockerX
git clone https://github.com/hildebrandmw/MemSnoop.jl MemSnoop
git clone https://github.com/hildebrandmw/SnoopAnalyzer.jl SnoopAnalyzer

julia --project=. -e "using Pkg; Pkg.build()"
