# Manifest

Below is summary of projects supporting this repo as well as resources provisioned on shared
machines for bookkeeping purposes.

```@contents
Pages = ["manifest.md"]
Depth = 3
```

## Supporting Projects



### [Docker](https://github.com/hildebrandmw/Docker.jl)

Julia interface to the Docker API for managing containers and gathering metrics. This 
package is based on the original [Docker](https://github.com/Keno/Docker.jl) package, but
updated to serve our own needs. I've also added CI to the build process.

#### TODO List (Low Priority)

- Add documentation of features in README. No need for auto docs.

- Eventually, I would like to get this merged with the original Docker package, which would
    likely involve:
    
    1. Forking the original Docker repo.
    2. Migrating the code in Docker to the forked Docker repo.
    3. Issue a string of pull requests to get the functionality migrated.

- The Docker daemon by default listens on a Unix socket. In order to get the 
    [HTTP](https://github.com/JuliaWeb/HTTP.jl) to talk to a Unix socket, I had to extend
    some of the methods in `HTTP`. Contributing this code to HTTP would be a good 
    contribution I think.



### [PAPI](https://github.com/hildebrandmw/PAPI.jl)

Updated bindings to the [PAPI Library](http://icl.utk.edu/papi/), forked from the original
[PAPI.jl](https://github.com/jakebolewski/PAPI.jl) which has not been updated in 4 years.
This package includes the PAPI executable for reproducibility, courtesy of 
[PAPIBuilder2](https://github.com/hildebrandmw/PAPIBuilder2), which is auto built with
[BinaryBuilder](https://github.com/JuliaPackaging/BinaryBuilder.jl).

In essence, this gives access to a processor's hardware event counters through `perf`.

#### TODO List (Low Priority)

- Get CI working for this package. I don't think the hardware performance counters are
    available in Travis Docker containers, so the current test suite fails due to a PAPI 
    error.

- Finish implementing the rest of the Low Level Library

- Implement the high level library, taking inspiration from the original PAPI implementation
    and the [python](https://github.com/flozz/pypapi) bindings.

- Add fuller documentation

- Document the Julia-side API that I use to interact with it. This side is mainly 
    responsible for automatically handling library initialization and cleanup.



### [PAPIBuilder2](https://github.com/hildebrandmw/PAPIBuilder2)

Builder for the PAPI library. Releases fetched when installing can be found here: 
<https://github.com/hildebrandmw/PAPIBuilder2/releases>



### [MemSnoop](https://github.com/hildebrandmw/MemSnoop.jl)

Snooping routines to gather metrics on running programs. Includes the following analyses:

- Idle page tracking
- Hardware performance counter tracking through [PAPI](https://github.com/hildebrandmw/MemSnoop.jl).

One of the big goals of this package is to reduce the number of third party dependencies
as much as possible since Idle Page Tracking requires Julia to be run as root.

#### TODO List (Med Priority)

- Add support for monitoring multiple processes.

- Move suitable code from [SnoopAnalyzer](https://github.com/hildebrandmw/SnoopAnalyzer.jl) 
    into MemSnoop.

- Have other people use this package to find bugs and improve documentation.



### [SnoopAnalyzer](https://github.com/hildebrandmw/SnoopAnalyzer.jl)

Analysis routines for MemSnoop that require external dependencies. This will probably 
eventually just be for plotting plus some other misc stuff.

#### TODO List (Low Priority)

- Documentation

- See when migration to [Makie](https://github.com/JuliaPlots/Makie.jl) is suitable. 
    Theoretically, the plotting recipe system for Makie might not rely on a macro, so 
    plotting recipes for MemSnoop might be able to be implemented straight in MemSnoop 
    without adding any dependencies.



### [ml-notebooks (private)](https://github.com/darchr/ml-notebooks)

Jupyter notebooks and scripts for research.



## Resources on Shared Machines

### Drives on `amarillo`

The drive
```
/data1/ml-dataset
```
on `amarillo` is the home of the datasets used.
