# Launcher

Launcher is the Julia package (sorry, I really, really like writing Julia code) for handling
the launching of containers, aggregation of results, binding containers with relevant datasets,
and generally making sure everything is working correctly. Documentation for this package
can be found in this section.

The functionality provided by this model is very straightforward and can probably be ported
to another language if needed.

Note that `Launcher` is built on top of two other packages:

* [Docker](https://github.com/hildebrandmw/Docker.jl) - Package for interacting with
    the Docker API.
* [SystemSnoop](https://github.com/hildebrandmw/SystemSnoop.jl) - Package for tracking the memory
    usage patterns of applications on the Linux operating system.

These two packages are still works in progress and documentation on them is forthcoming.
However, I plan on registering at least Docker and probably SystemSnoop as well as soon as I
take the time to get them production ready.

## Temporary Documentation

```@docs
Launcher.run
Launcher.AbstractWorkload
Launcher.startfile
Launcher.runcommand
Launcher.create
```