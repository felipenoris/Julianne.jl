
const HOST = HostState(
    ip"127.0.0.1",
    8023,
    "/Users/noronha/julianne",
    10
)

# List of packages to be tested
push!(HOST.packages, PkgRef("BusinessDays"))
push!(HOST.packages, PkgRef("Calculus"))
push!(HOST.packages, PkgRef("Cbc"))
push!(HOST.packages, PkgRef("Clp"))
push!(HOST.packages, PkgRef("Compat"))
push!(HOST.packages, PkgRef("Coverage"))
push!(HOST.packages, PkgRef("DataStructures"))
push!(HOST.packages, PkgRef("FileIO"))
push!(HOST.packages, PkgRef("FixedSizeArrays"))
push!(HOST.packages, PkgRef("ForwardDiff"))
push!(HOST.packages, PkgRef("Gadfly"))
push!(HOST.packages, PkgRef("HttpParser"))
push!(HOST.packages, PkgRef("HttpServer"))
push!(HOST.packages, PkgRef("Images"))
push!(HOST.packages, PkgRef("InterestRates"))
push!(HOST.packages, PkgRef("JSON"))
push!(HOST.packages, PkgRef("JuMP"))
push!(HOST.packages, PkgRef("LightXML"))
push!(HOST.packages, PkgRef("Logging"))
push!(HOST.packages, PkgRef("NullableArrays"))
push!(HOST.packages, PkgRef("Optim"))
push!(HOST.packages, PkgRef("PyCall"))
push!(HOST.packages, PkgRef("PyPlot"))
push!(HOST.packages, PkgRef("RCall"))
push!(HOST.packages, PkgRef("StatsBase"))


# Set last known Commit which all tests pass
HOST.tail_sha = "11a34aac2d9b859cf5266f5571797e41748e10e0"
