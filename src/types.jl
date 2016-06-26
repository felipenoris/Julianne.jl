
type Commit
	sha::AbstractString
	subject::AbstractString
	branch::AbstractString

	Commit() = new("", "", "")
	Commit(sha, sub) = Commit(sha, sub, "master") # defaults to julia's master branch
	Commit(sha::AbstractString, sub::AbstractString, br::AbstractString) = new(sha, sub, br)
end

type WorkerInfo
	id::AbstractString
	julia_version::VersionNumber
	versioninfo::AbstractString

	WorkerInfo(id) = begin
		io = IOBuffer()
		versioninfo(io, false)
		s = bytestring(io)
		close(io)
		new(id, VERSION, s)
	end
end

type WorkerSock
	worker::WorkerInfo
	connection::TCPSocket
end

type PkgRef
	name::AbstractString
	url::AbstractString

	PkgRef(name, url) = new(name, url)
end

type TestResult
	ref::PkgRef
	passed::Bool
	error_message::AbstractString
	version::VersionNumber
	commit::Commit # identifies the commit referente on julia's master branch
end

type HostState
	ip::AbstractString
	port::Int
	working_dir::AbstractString
	lastupdate::DateTime
	commit_list::Vector{Commit} # Ordered list of commits
	results_dict::Dict{Commit, Vector{TestResult}} # maps Commit to test status. If it's not there, hasn't been dispached yet for testing
	workersocks::Vector{WorkerSock} # registered workers
	packages::Vector{PkgRef}
	head_sha::AbstractString

	HostState(ip, port, working_dir) = new(ip, port, working_dir, now(), Array(AbstractString, 0), Dict{AbstractString, Vector{TestResult}}(), Array(WorkerSock, 0), Array(PkgRef, 0), "")
end

# TODO: show() methods ...
sha_abbrev(c::Commit) = c.sha[1:7]
sha_abbrev(r::PkgRef) = sha_abbrev(r.commit)
