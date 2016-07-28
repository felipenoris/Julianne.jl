
# Julianne

[![Build Status](https://travis-ci.org/felipenoris/Julianne.jl.svg?branch=master)](https://travis-ci.org/felipenoris/Julianne.jl)

Automated package testing infrastructure and distributed testing for Julia's master branch.

Travis is currently testing `Base.runtests()`. Meet @juliannebot: she will run `Pkg.test()` on a list of selected packages, for every commit on Julia's master branch. May run benchmark tests also...

Please, donate your computer power! \o/

*JuliaCon2016 hackathon*

## Requirements

Julia 0.4

Docker

## Configuration

Edit `hostconfig.jl`. 

```julia
# List of packages to be tested
register_package("BusinessDays")
register_package("Calculus")

# Packages that are not in METADATA can be registered using a URL
register_package("PassingPkg", "https://github.com/juliannebot/PassingPkg.jl.git")
#...

# Set last known Commit which all tests pass
settail("0030eec2f332f353e6890ca289ac2aca55532dde")
```
## Usage

### Host

```julia
julia> using Julianne

julia> Julianne.start(ip"127.0.0.1", 8023) # Will listen for connections on provided ip/port
```

### Worker

```julia
julia> using Julianne

julia> Julianne.Worker.start("worker 1", ip"127.0.0.1", 8023) # will connect to a Host
```

Both Host and Worker will log to file `julianne.log` at current directory (`pwd()`).
