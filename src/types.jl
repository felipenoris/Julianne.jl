
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
	OS::Symbol
	MACHINE::AbstractString
	WORD_SIZE::Int

	WorkerInfo(id) = begin
		io = IOBuffer()
		versioninfo(io, false)
		s = bytestring(io)
		close(io)
		new(id, VERSION, s, Sys.OS_NAME, Sys.MACHINE, Sys.WORD_SIZE) # for v0.5, names are different
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

@enum WorkerTaskState UNTESTED=1 PASSED=2 FAILURE=3 NOT_CONCLUSIVE=4

type WorkerTask
	ref::PkgRef
	state::WorkerTaskState
	error_message::AbstractString
	version::VersionNumber
	head_commit::Commit # identifies the commit referente on julia's master branch
	target_commit::Commit # identifies the commit referente on julia's master branch
	worker::WorkerInfo # Who tested this
end

type HostState
	ip::IPAddr
	port::Int
	working_dir::AbstractString
	lastupdate::DateTime
	commit_list::Vector{Commit} # Ordered list of commits
	results_dict::Dict{Commit, Vector{WorkerTask}} # maps Commit to test status. If it's not there, hasn't been dispached yet for testing. The vector allows for one test for each package.
	workersocks::Vector{WorkerSock} # registered workers
	packages::Vector{PkgRef}
	head_sha::AbstractString

	HostState(ip, port, working_dir) = new(ip, port, working_dir, now(), Array(AbstractString, 0), Dict{AbstractString, Vector{WorkerTask}}(), Array(WorkerSock, 0), Array(PkgRef, 0), "")
end

# TODO: show() methods ...
sha_abbrev(c::Commit) = c.sha[1:7]
sha_abbrev(r::PkgRef) = sha_abbrev(r.commit)
