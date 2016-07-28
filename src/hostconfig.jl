
# List of packages to be tested
register_package("BusinessDays")
register_package("Calculus")
register_package("Clp")
register_package("Compat")
register_package("DataStreams")
register_package("DataFrames")
register_package("FixedSizeArrays")
register_package("HttpParser")
register_package("HttpServer")
register_package("InterestRates")
register_package("JSON")
register_package("Logging")
register_package("NaturalSort")
register_package("Optim")
register_package("PyCall")
register_package("StatsBase")

# known to fail: Cbc, Coverage, DataStructures, ForwardDiff, Gadfly, Images, JuMP, LightXML, NullableArrays, RCall, FilePaths

# Set last known Commit which all tests pass
settail("e717ded47a55d3526a10207d8d75ae5c9ab9646f")
