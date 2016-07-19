
# Worker routines

module Worker

import ..PkgRef
import ..Commit
import ..sha_abbrev
import ..WorkerInfo
import ..WorkerTaskRequest
import ..WorkerTaskResponse
import ..rm_if_exists

const SRC_DIR = dirname(@__FILE__)

# Utility function for method build
function _replace_on_1st_line(filepath, before_str, after_str)
    f = open(filepath)
    l = readlines(f)
    close(f)
    l[1] = replace(l[1], before_str, after_str)
    f = open(filepath, "w")
    write(f, l)
    flush(f)
    close(f)
end

# Utility function for method run_container
function _has_string(filepath, str)
    f = open(filepath)
    const r_str = Regex(str)
    while !eof(f)
        m = match(r_str, readline(f))
        if !isa(m, Void)
            close(f)
            return true
        end
    end
    close(f)
    return false
end

# updates HEAD and TARGET files used by the Dockerfile
function update_docker_marker(marker_name::AbstractString, sha::AbstractString)
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

# Build docker images
function build(tail::Commit, target::Commit)
    const tail_sha_abv = sha_abbrev(tail)
    const target_sha_abv = sha_abbrev(target)
    const filepath_docker_tail = joinpath(SRC_DIR, "docker", "Dockerfile.tail")
    const filepath_docker_target = joinpath(SRC_DIR, "docker", "Dockerfile.target")
    try
        # Build tail
        info("Building julia docker image for tail $tail_sha_abv...")
        update_docker_marker("TAIL", tail.sha)
        run(`docker build -t julia:$tail_sha_abv -f $filepath_docker_tail $(joinpath(SRC_DIR, "docker"))`)
        info("Done building julia docker image for tail $tail_sha_abv.")

        # Build target
        info("Building julia docker image for target $target_sha_abv...")
        update_docker_marker("TARGET", target.sha)
        _replace_on_1st_line(filepath_docker_target, "tail", tail_sha_abv) # replace image name inside Dockerfile.target
        run(`docker build -t julia:$target_sha_abv -f $(joinpath(SRC_DIR, "docker", "Dockerfile.target")) $(joinpath(SRC_DIR, "docker"))`)
        info("Done building julia docker image for target $target_sha_abv.")

    catch e
        warn("Error building julia docker images: $e.")
    finally
        # Put it back, so it will work next time
        _replace_on_1st_line(filepath_docker_target, tail_sha_abv, "tail")
    end
end

function run_container!(response::WorkerTaskResponse, c::Commit, pkg::PkgRef)
    const key = string(hash(rand()))[1:6] # random generated filename for log output
    const output_file = "out_" * key * ".log"
    const err_file = "errs_" * key * ".log"
    const image = "julia:$(sha_abbrev(c))"

    try 
        info("Going to test $(pkg.name) at $(image)")
        cmd = `docker run --rm $image ./julia/julia -e (Pkg.update();Pkg.test(\"$(pkg.name)\"))`
        println(cmd)
        run(pipeline(cmd, stdout=output_file, stderr=err_file))
        info("Test finished for $(pkg.name)")

        # Did tests pass?
        if _has_string(err_file, "$(pkg.name) tests passed")
            response.status = :PASSED
        else
            response.status = :FAILED
            # TODO: set response.error_message
        end
    catch e
        warn("error $e")
        if isfile(output_file) && isfile(err_file)
            response.status = :FAILED
            # TODO: set response.error_message
        end
    finally
        rm_if_exists(output_file)
        rm_if_exists(err_file)
    end
end

function testpkg(wi::WorkerInfo, request::WorkerTaskRequest) # :: WorkerTaskResponse
    response = WorkerTaskResponse(request, :UNTESTED, "", VERSION, wi) # TODO: change VERSION to Pkg version
    try
        build(request.tail, request.target)
        run_container!(response, request.target, request.pkg)
    catch e
        response.status = :UNKNOWN
        response.error_message = "$e"
        warn("Error running testpkg: $e")
    finally
        return response
    end
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
        response = testpkg(wi, request)
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
