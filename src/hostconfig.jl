
const HOST = HostState(
    ip"127.0.0.1",
    8023,
    "/Users/noronha/julianne",
    10
)

# List of packages to be tested
push!(HOST.packages, PkgRef("PassingPkg", "https://github.com/juliannebot/PassingPkg.jl.git"))
push!(HOST.packages, PkgRef("FailingPkg", "https://github.com/juliannebot/FailingPkg.jl.git"))

# Set last known Commit which all tests pass
HOST.tail_sha = "11a34aac2d9b859cf5266f5571797e41748e10e0"
