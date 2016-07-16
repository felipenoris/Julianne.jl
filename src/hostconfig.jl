
const HOST = HostState(
    ip"127.0.0.1",
    8023,
    "/Users/felipenoris/julianne"
)

# List of packages to be tested
push!(HOST.packages, PkgRef("PassingPkg", "https://github.com/juliannebot/PassingPkg.jl.git"))
push!(HOST.packages, PkgRef("FailingPkg", "https://github.com/juliannebot/FailingPkg.jl.git"))

# Set last known Commit which all tests pass
HOST.tail_sha = "e62b204599418164e8a3cbcf88dc6ff556c3ad83"
