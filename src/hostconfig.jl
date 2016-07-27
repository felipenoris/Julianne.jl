
const HOST = HostState(
    ip"127.0.0.1",
    8023,
    "/Users/noronha/julianne",
    60 * 60 # sleep time in seconds
)

# List of packages to be tested
push!(HOST.packages, PkgRef("BusinessDays"))
push!(HOST.packages, PkgRef("Calculus"))
push!(HOST.packages, PkgRef("Clp"))
push!(HOST.packages, PkgRef("Compat"))
push!(HOST.packages, PkgRef("DataStreams"))
push!(HOST.packages, PkgRef("DataFrames"))
push!(HOST.packages, PkgRef("FixedSizeArrays"))
push!(HOST.packages, PkgRef("HttpParser"))
push!(HOST.packages, PkgRef("HttpServer"))
push!(HOST.packages, PkgRef("InterestRates"))
push!(HOST.packages, PkgRef("JSON"))
push!(HOST.packages, PkgRef("Logging"))
push!(HOST.packages, PkgRef("MappedArrays"))
push!(HOST.packages, PkgRef("NaturalSort"))
push!(HOST.packages, PkgRef("Optim"))
push!(HOST.packages, PkgRef("PyCall"))
push!(HOST.packages, PkgRef("StatsBase"))

# known to fail: Cbc, Coverage, DataStructures, ForwardDiff, Gadfly, Images, JuMP, LightXML, NullableArrays, RCall, FilePaths

# Set last known Commit which all tests pass
HOST.tail_sha = "0030eec2f332f353e6890ca289ac2aca55532dde"
