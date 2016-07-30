
# List of packages to be tested
register_package("BusinessDays")
register_package("Calculus")
register_package("Clp")
register_package("Compat")
register_package("DataStreams")
register_package("DataFrames")
register_package("Documenter")
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
settail("ba46baf63fa5e9665aa6c7cf5c4bc473266b6212")
