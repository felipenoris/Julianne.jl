
const HOST = HostState(
	"localhost",
	8023,
	"/julianne"
)

# List of packages to be tested
push!(HOST.packages, PkgRef("PassingPkg", "https://github.com/juliannebot/PassingPkg.jl.git"))
push!(HOST.packages, PkgRef("FailingPkg", "https://github.com/juliannebot/FailingPkg.jl.git"))

# Set's head commit
HOST.head_sha = "e62b204599418164e8a3cbcf88dc6ff556c3ad83"
