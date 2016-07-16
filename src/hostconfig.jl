
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
#HOST.tail_sha = "e62b204599418164e8a3cbcf88dc6ff556c3ad83"
HOST.tail_sha = "4b0c60f2edff120569d797fcb63c99bfc83e1928"
