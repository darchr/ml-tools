# ML-Tools

| **Documentation** | **Build Status** |
|:---:|:---:|
[![][docs-latest-img]][docs-latest-url] | [![][travis-img]][travis-url] |

Collection of tools for analyzing machine learning workloads.

## Installation

Clone the repo with
```sh
git clone https://github.com/darchr/ml-tools
```
Fetch dependencies with
```sh
cd ml-tools/deps
./init.sh
```

## Subpackages

| **Package** | **Build Status** | **Documentation** |
|:-----------:|:----------------:|:-----------------:|
| [Docker](https://github.com/hildebrandmw/Docker.jl)   | [![][dockerx-travis-img]][dockerx-travis-url]   |                                           |
| [SystemSnoop](https://github.com/hildebrandmw/SystemSnoop.jl) | [![][memsnoop-travis-img]][memsnoop-travis-url] | [![][docs-latest-img]][memsnoop-docs-url] |
| [PAPI](https://github.com/hildebrandmw/PAPI.jl)         | [![][papi-travis-img]][papi-travis-url]         |                                           |
| [PAPIBuilder2](https://github.com/hildebrandmw/PAPIBuilder2) | [![][papibuilder-travis-img]][papibuilder-travis-url] |                                |


[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: http://arch.cs.ucdavis.edu/ml-tools/latest/

[travis-img]: https://travis-ci.org/darchr/ml-tools.svg?branch=master
[travis-url]: https://travis-ci.org/darchr/ml-tools

[dockerx-travis-img]: https://travis-ci.org/hildebrandmw/Docker.jl.svg?branch=master
[dockerx-travis-url]: https://travis-ci.org/hildebrandmw/Docker.jl 

[memsnoop-travis-img]: https://travis-ci.org/hildebrandmw/SystemSnoop.jl.svg?branch=master
[memsnoop-travis-url]: https://travis-ci.org/hildebrandmw/SystemSnoop.jl 
[memsnoop-docs-url]: https://hildebrandmw.github.io/SystemSnoop.jl/latest

[papi-travis-img]: https://travis-ci.org/hildebrandmw/PAPI.jl.svg?branch=master
[papi-travis-url]: https://travis-ci.org/hildebrandmw/PAPI.jl 

[papibuilder-travis-img]: https://travis-ci.org/hildebrandmw/PAPIBuilder2.svg?branch=master
[papibuilder-travis-url]: https://travis-ci.org/hildebrandmw/PAPIBuilder2 
