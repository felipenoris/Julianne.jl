
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
    ARCH::Symbol
    OS::Symbol
    MACHINE::AbstractString
    WORD_SIZE::Int

    WorkerInfo(id) = begin
        io = IOBuffer()
        versioninfo(io, false)
        s = bytestring(io)
        close(io)
        new(id, VERSION, s, Sys.ARCH, Sys.OS_NAME, Sys.MACHINE, Sys.WORD_SIZE) # for v0.5, names are different
    end
end

type WorkerSock
    worker::WorkerInfo
    connection::TCPSocket
end

immutable PkgRef
    name::AbstractString
    url::AbstractString

    PkgRef(name, url) = new(name, url)
end

type WorkerTaskRequest
    pkg::PkgRef
    target::Commit # Julia's commit sha to be tested
    tail::Commit # Oldest known commit which all tests pass
end

type WorkerTaskResponse
    request::WorkerTaskRequest
    status::Symbol
    error_message::AbstractString
    version::VersionNumber # Package Version info
    worker::WorkerInfo # Who tested this
end

type HostState
    ip::IPAddr
    port::Int
    working_dir::AbstractString
    lastupdate::DateTime
    commits::Vector{Commit} # Ordered list of commits
    results::Dict{Commit, Vector{WorkerTaskResponse}} # maps Commit to test status. If it's not there, hasn't been dispached yet for testing. The vector allows for one test for each package.
    workers::Vector{WorkerSock} # registered workers
    packages::Vector{PkgRef}
    tail_sha::AbstractString
    status::Symbol # :IDLE, :BUSY
    idle_c::Condition
    #busy_c::Condition

    HostState(ip, port, working_dir) = new(ip, port, working_dir, now(), Array(AbstractString, 0), Dict{AbstractString, Vector{WorkerTaskResponse}}(), Array(WorkerSock, 0), Array(PkgRef, 0), "", :IDLE, Condition())
end

# TODO: show() methods ...
sha_abbrev(sha::AbstractString) = sha[1:7]
sha_abbrev(c::Commit) = sha_abbrev(c.sha)