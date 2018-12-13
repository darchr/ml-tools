# French Street Name Signs (FSNS)

* <https://github.com/tensorflow/models/tree/master/research/street>
* <http://rrc.cvc.uab.es/?ch=6>

## Downloading and Installing

Navigate to where you want to download the dataset. Run the following commands:
```sh
# Start Julia with 10 workers. Can change number of workers if desired
julia -p10
```

```julia
julia> using Pkg

julia> Pkg.develop("<path-to-ml-tools>/datasets/fsns/Downloader")

julia> using Downloader

julia> Downloader.downloadall()
```
