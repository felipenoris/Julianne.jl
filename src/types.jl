
sha_abbrev(sha::AbstractString) = sha[1:7]

type Commit
    sha::AbstractString
    subject::AbstractString
    branch::AbstractString

    Commit() = new("", "", "")
    Commit(sha, sub) = Commit(sha, sub, "master") # defaults to julia's master branch
    Commit(sha::AbstractString, sub::AbstractString, br::AbstractString) = new(sha, sub, br)
end

sha_abbrev(c::Commit) = sha_abbrev(c.sha)
==(a::Commit, b::Commit) = a.sha == b.sha
hash(c::Commit, h::UInt = UInt(1)) = hash(c.sha, h)

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
    PkgRef(name) = PkgRef(name, "")
end

type WorkerTaskRequest
    pkg::PkgRef # pkg to be tested
    target::Commit # Julia's commit sha to be tested
    tail::Commit # Oldest known commit which all tests pass
    pkg_list::Vector{PkgRef} # Full list of packages, used to build the docker image
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
    workers_c::Condition
    sleep_time::Int # seconds

    HostState(ip, port, working_dir, sleep_time) = new(ip, port, working_dir, now(), Array(AbstractString, 0), Dict{AbstractString, Vector{WorkerTaskResponse}}(), Array(WorkerSock, 0), Array(PkgRef, 0), "", :IDLE, Condition(), Condition(), sleep_time)
end

gettail(hs::HostState) = Commit(hs.tail_sha, hs.commits[end].subject)

function report_str(h::HostState) # :: String
    r = """
    Current tail: $(h.tail_sha)
    # of available workers: $(length(h.workers))
    """

    for c in h.commits
        r = r * "$(sha_abbrev(c)) : $(getstatus(c))"
        if c.sha == tail_sha
            break
        end
    end
    r
end
