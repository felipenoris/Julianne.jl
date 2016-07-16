
# host routines

module Host

import Base.IPAddr
import ..HostState
import ..WorkerTaskRequest
import ..WorkerTaskResponse
import ..Worker
import ..PkgRef
import ..Commit
import ..Worker
import ..WorkerSock
import ..WorkerInfo
import ..HOST
import ..TimeoutException
import ..timeout
import ..sha_abbrev

rm_if_exists(f) = isfile(f) && rm(f)

wait_host(h::HostState = HOST) = wait(h.idle_c)
isidle(h::HostState = HOST) = h.status == :IDLE
isbusy(h::HostState = HOST) = h.status == :BUSY

workerscount(h::HostState = HOST) = length(h.workers)

function busy!(h::HostState = HOST)
    h.status = :BUSY
end

function idle!(h::HostState = HOST)
    h.status = :IDLE
    notify(h.idle_c)
end

# Get's the latest julia's repo and updates list of commits.
function pull_julia_repo()
    info("Updating julia repo...")
    
    if !isdir(HOST.working_dir)
        throw(ErrorException("Working directory not found: $(HOST.working_dir)"))
    end

    cd(HOST.working_dir)

    if !isdir("julia")
        # clone repo
        run(`git clone https://github.com/JuliaLang/julia.git`)
    end

    rm_if_exists("commits.txt")
    rm_if_exists("subjects.txt")
    cd("julia")
    run(`git pull`)
    run(pipeline(`git log --pretty=format:%H`, joinpath("..", "commits.txt")))
    run(pipeline(`git log --pretty=format:%s`, joinpath("..", "subjects.txt")))
    cd("..")

    file_c = open("commits.txt")
    file_s = open("subjects.txt")
    c = ""

    empty!(HOST.commits)

    while c != HOST.tail_sha
        c = chomp(readline(file_c))
        s = chomp(readline(file_s))

        println("$c : $s")
        push!(HOST.commits, Commit(c, s))
    end

    close(file_c)
    close(file_s)
    rm_if_exists("commits.txt")
    rm_if_exists("subjects.txt")
    info("...done!")
end

# listens for new connections on background
function schedule_listen_task()
    @schedule begin
        srvr = listen(HOST.ip, HOST.port)
        while true
            socket = accept(srvr)
            try
                handshake(socket)
            catch e
                warn("Couldn't accept connection: $e")
                isopen(socket) && close(socket)
            end
        end
    end
end

function handshake(socket::TCPSocket)
    serialize(socket, :HELLO_WORKER)
    resp = deserialize(socket)
    resp != :HELLO_MASTER && throw(ErrorException("Unexpected handshake: '$resp'."))
    serialize(socket, :WHO_ARE_YOU)
    worker = deserialize(socket)
    !isa(worker, WorkerInfo) && throw(ErrorException("Unexpected handshake: Should receive WorkerInfo. Got '$worker'."))
    add_worker!(WorkerSock(worker, socket))
    info("Host: New worker connected! Go for it, '$(worker.id)' !")
end

function start(ip::IPAddr, port::Int, working_dir="")
    HOST.ip = ip
    HOST.port = port
    start(working_dir)
end

function start(working_dir="")
    if working_dir != "" 
        HOST.working_dir = working_dir
    end

    start()
end

function checkhostconfig()
    if isempty(HOST.packages)
        throw(ErrorException("No packages to be tested. Will stop the HOST."))
    end

    if !isdir(HOST.working_dir)
        throw(ErrorException("Working directory not found: $(HOST.working_dir)"))
    end
end

# Set new TAIL for the HOST
function settail(c::Commit)
    HOST.tail_sha = c.sha
    info("Ladies and Gentlemen: our new TAIL is $(sha_abbrev(c))!")
end

istail(c::Commit) = HOST.tail_sha == c.sha

gettail() = Commit(HOST.tail_sha, "")

function start()
    # Checks for Host configuration consistency
    checkhostconfig()

    schedule_listen_task()

    # starting local workers
    if nprocs() == 1
        info("No local workers will be created. Use addprocs(n) before running `start_host()` to allow for local workers.")
    else
        for ww in procs()
            ww == 1 && continue
            @spawnat ww Worker.start("Local worker $ww", HOST.ip, HOST.port)
        end
    end

    i = 1
    # main loop for server work
    @async while true
        
        pull_julia_repo()
        info("Starting iteration $i...")
        # dispatch workload for workers
        start_next_test()

        info("Test iteration $i results:")
        show(HOST.results)
        i += 1
    end

    yield()
end

include("hostlogic.jl")

# TODO: listen to github mentions

# TODO: post results

# TODO: update jpeg for results that readme.md shows

end # module
