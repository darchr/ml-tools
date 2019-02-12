#!/bin/bash

# Fetch git repos
git clone https://github.com/hildebrandmw/PAPI.jl PAPI
git clone https://github.com/hildebrandmw/Docker.jl Docker
git clone https://github.com/hildebrandmw/SystemSnoop.jl SystemSnoop
git clone https://github.com/hildebrandmw/PCM.jl PCM

julia --project=. -e "using Pkg; Pkg.build()"
