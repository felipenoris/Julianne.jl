
# Worker routines

module Worker

import ..PkgRef
import ..Commit
import ..sha_abbrev
import ..WorkerInfo
import ..WorkerTaskRequest
import ..WorkerTaskResponse

const SRC_DIR = dirname(@__FILE__)

# updates HEAD and TARGET files used by the Dockerfile
function refresh_docker_marker(marker_name::AbstractString, sha::AbstractString)
    try
        marker_filepath = joinpath(SRC_DIR, "docker", marker_name)
        if isfile(marker_filepath)
            rm(marker_filepath)
        end

        marker_file = open(marker_filepath, "w")
        write(marker_file, sha)
        close(marker_file)
    catch e
        warn("error $e")
    end
end

# builds just the tail
function build_tail(tail::Commit)
    try
        run(`docker build -t julia:$(sha_abbrev(tail)) -f $(joinpath(SRC_DIR, "docker", "Dockerfile.tail")) $(joinpath(SRC_DIR, "docker"))`)
    catch e
        warn("error $e")
    end
end

# builds the target commit for testing
function build_target(target::Commit)
    try
        build_tail()
        run(`docker build -t julia:$(sha_abbrev(target)) -f $(joinpath(SRC_DIR, "docker", "Dockerfile.target")) $(joinpath(SRC_DIR, "docker"))`)
    catch e
        warn("error $e")
    end
end

#function testpkg(pkg::PkgRef)
#   try
#       build_target(pkg)
#       Pkg.clone(pkg.url)
#       Pkg.test(pkg.name)
#       # TODO: record result of versioninfo(io)
#   catch e
#       # TODO : catch STDERR messages, see redirect_stdout, redirect_stderr
#       WorkerTask(pkg, false, "$e")
#   end
#
#   return WorkerTask(pkg, true, "")
#end

# connects to host and waits for the workload
function start(my_worker_id::AbstractString, ip, port)
    wi = WorkerInfo(my_worker_id)
    sock = connect(ip, port)
    info("Worker connected to Host!")
    try
        handshake(sock, wi)
    catch e
        warn("Couldn't connect to host: $e.")
        isopen(sock) && close(sock)
    end

    #while true
    #       pkgref = deserialize(c)    # <--- Block wait for a request
    #       println("going to test $(pkgref.name)")
    #       result = testpkg(pkgref)
    #       println("Received request for $(pkgref.name). Response $result.")
    #       serialize(c, result)        # <--- send back response
    #       println("Result was sent to Host!")
    #end
end

function handshake(sock::TCPSocket, wi)
    resp = deserialize(sock)
    resp != :HELLO_WORKER && throw(ErrorException("Unexpected handshake: '$resp'."))
    serialize(sock, :HELLO_MASTER)
    resp = deserialize(sock)
    resp != :WHO_ARE_YOU && throw(ErrorException("Unexpected handshake: '$resp'."))
    serialize(sock, wi)
end

end # module
