
type Commit
	sha::AbstractString
	subject::AbstractString

	Commit() = new("", "")
end

abstract TestWorker

type HostWorker <: TestWorker
end

type RemoteWorker <: TestWorker
	conn::TCPSocket
end

type PkgRef
	name::AbstractString
	url::AbstractString
	commit::Commit

	PkgRef(name, url) = new(name, url, Commit())
end

type TestResult
	ref::PkgRef
	passed::Bool
	error_message::AbstractString
end

type PkgStatus
	ref::PkgRef
	status::AbstractString # test status
	version::VersionNumber # pkg version
end

type HostState
	lastupdate::DateTime
	commit_list::Vector{Commit} # Ordered list of commits
	commit_dict::Dict{Commit, Vector{PkgStatus} } # maps Commit to test status. If it's not there, hasn't been dispached yet for testing
	workers::Vector{TestWorker} # registered workers
	packages::Vector{PkgRef}
	head_sha::AbstractString

	HostState() = new(now(), Array(AbstractString, 0), Dict{AbstractString, Vector{PkgStatus}}(), Array(TestWorker, 0), Array(PkgRef, 0), "")
end

type HostConfig
	ip::AbstractString
	port::Int
	dir::AbstractString
end

# TODO: show() methods ...
sha_abbrev(c::Commit) = c.sha[1:7]
sha_abbrev(r::PkgRef) = sha_abbrev(r.commit)
