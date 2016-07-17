
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
        refresh_docker_marker("TAIL", tail.sha)
        run(`docker build -t julia:$(sha_abbrev(tail)) -f $(joinpath(SRC_DIR, "docker", "Dockerfile.tail")) $(joinpath(SRC_DIR, "docker"))`)
    catch e
        warn("error $e")
    end
end

# builds the target commit for testing
function build_target(target::Commit)
    try
        refresh_docker_marker("TARGET", target.sha)
        run(`docker build -t julia:$(sha_abbrev(target)) -f $(joinpath(SRC_DIR, "docker", "Dockerfile.target")) $(joinpath(SRC_DIR, "docker"))`)
    catch e
        warn("error $e")
    end
end

function run_container(c::Commit, pkg::PkgRef)
    try
        # docker run -it --rm julia:beab3b6 ./julia/julia -e 'println("hello")'
        output = string(hash(rand())) * ".log" # random generated filename for log output
        run(`docker run -it --rm julia:$(sha_abbrev(c)) ./julia/julia -e ' (Pkg.clone("$(pkg.url)") ; Pkg.test("$(pkg.name)") )' > $(output)`)
    catch e
        warn("error $e")
    end
end

function testpkg(request::WorkerTaskRequest) # :: WorkerTaskResponse
   try
       build_tail(request.tail)
       build_target(request.target)
       run_container(request.target, request.pkg)
   catch e
       # TODO : catch STDERR messages, see redirect_stdout, redirect_stderr
       WorkerTask(pkg, false, "$e")
   end

   return WorkerTask(pkg, true, "")
end

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

    while true
        request = deserialize(sock) :: WorkerTaskRequest
        info("worker $my_worker_id going to test $(request.pkg.name).")
        sleep(10 + 5*rand()) # TODO
        response = WorkerTaskResponse(request, :FAILURE, "", VERSION, wi)
        serialize(sock, response)
        info("worker $my_worker_id finished tests for $(request.pkg.name).")
    end
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
