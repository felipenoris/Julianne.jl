
# host routines

import Base.IPAddr

rm_if_exists(f) = isfile(f) && rm(f)
istail(c::Commit) = HOST.tail_sha == c.sha
gettail() = Commit(HOST.tail_sha, "")
wait_host() = wait(HOST.idle_c)
isidle() = HOST.status == :IDLE
isbusy() = HOST.status == :BUSY
workerscount() = length(HOST.workers)
getstatus(wtr::WorkerTaskResponse) = wtr.status
getstatus(sym::Symbol) = sym
ispending(item) = getstatus(item) ∈ [ :UNTESTED, :PENDING, :PENDING_WITH_FAILURE, :PENDING_WITH_UNKNOWN ]
isdone(item) = !ispending(item)
hasfailure(item) = getstatus(item) ∈ [ :FAILED, :PENDING_WITH_FAILURE ]
isunknown(item) = getstatus(item) ∈ [ :UNKNOWN, :PENDING_WITH_UNKNOWN ]
busy!() = (HOST.status = :BUSY)
idle!() = (HOST.status = :IDLE; notify(HOST.idle_c))

"""
    getstatus(c::Commit) :: Symbol

:PASSED, :FAILED, :UNKNOWN
:UNTESTED, :PENDING, :PENDING_WITH_FAILURE, :PENDING_WITH_UNKNOWN
"""
function getstatus(c::Commit) # :: Symbol
    # No tests yet...
    if !haskey(HOST.results, c)
        return :UNTESTED
    end

    responses = HOST.results[c] # ::Vector{WorkerTaskResponse}
    status_set = getstatusset(responses)
    
    if length(responses) != length(HOST.packages)
        # there are pending tests
        if :FAILED ∈ status_set
            return :PENDING_WITH_FAILURE
        elseif :UNKNOWN ∈ status_set
            return :PENDING_WITH_UNKNOWN
        else
            return :PENDING
        end
    else
        # all tests are done
        if :FAILED ∈ status_set
            return :FAILED
        elseif :UNKNOWN ∈ status_set
            return :UNKNOWN
        else
            return :PASSED
        end
    end
end

# Get's the latest julia's repo and updates list of commits.
function pull_julia_repo()
    @info("Updating julia repo...")

    if !isdir(HOST.working_dir)
        throw(ErrorException("Working directory not found: $(HOST.working_dir)"))
    end
    cd(HOST.working_dir)

    # Clone julia repo if it's not found on HOST.working_dir
    if !isdir("julia") 
        @info("Clonning julia repo at $(HOST.working_dir)")
        run(`git clone https://github.com/JuliaLang/julia.git`)
    else
        julia_dir = joinpath(HOST.working_dir, "julia")
        @info("Found julia repo at $julia_dir")
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

        println("$(sha_abbrev(c)) : $s")
        push!(HOST.commits, Commit(c, s))
    end

    close(file_c)
    close(file_s)
    rm_if_exists("commits.txt")
    rm_if_exists("subjects.txt")
    @info("...done!")
end

# listens for new connections on background
function schedule_listen_task()
    @schedule begin
        srvr = listen(HOST.ip, HOST.port)
        while true
            socket = accept(srvr)
            @async begin
                try
                    handshake(socket)
                catch e
                    @warn("Couldn't accept connection: $e")
                    isopen(socket) && close(socket)
                end
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
    @info("Host: New worker connected! Go for it, '$(worker.id)' !")
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
    @info("Ladies and Gentlemen: our new TAIL is $(sha_abbrev(c))!")
end

function start()
    # Checks for Host configuration consistency
    checkhostconfig()
    schedule_listen_task()

    # start local workers
    if nprocs() == 1
        @info("No local workers will be created. Use addprocs(n) before running `start_host()` to allow for local workers.")
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
        @info("Starting iteration $i...")
        # dispatch workload
        start_next_test()
        @info("Test iteration $i results:")
        @info(report_str(HOST))
        i += 1
    end
    yield()
end

function gettestedpkg(c::Commit) # :: Set{PkgRef}
    r = Set()
    if haskey(HOST.results, c)
        responses = HOST.results[c]
        for wtr in responses
            push!(r, wtr.request.pkg)
        end
    end
    return r
end

function getuntestedpkg(c::Commit)
    tested = gettestedpkg(c)
    return setdiff(HOST.packages, tested)
end

"""
    getstatusset(v::Vector{WorkerTaskResponse}) # :: Set{Symbol}

Iterate over all responses and gathers status in a Set.
"""
function getstatusset(v::Vector{WorkerTaskResponse}) # :: Set{Symbol}
    r = Set{Symbol}()
    for wtr in v
        push!(r, getstatus(wtr))
    end
    return r
end

# Send workload to workers
function start_next_test()
    for tc in HOST.commits
        if isdone(tc)
            # This Commit is done testing
            if hasfailure(tc)
                @info("$(sha_abbrev(tc)) is done testing and has FAILURES.")
                # TODO: This may do bisection in the future...
                # For now, go test the next Commit in list until we reach the TAIL
                if istail(tc)
                    return  # Does nothing until we have new Commits to test
                else
                    continue # goes to next Commit
                end
            else
                if gettail() != tc
                    # YAY! This is our new TAIL!
                    @info("$(sha_abbrev(tc)) is done testing and PASSED.")
                    settail(tc)
                else
                    @info("Nothing to do... Let's get some sleep.")
                    sleep(HOST.sleep_time)
                end
                return
            end
        else
            # This Commit has pending tests
            @info("$(sha_abbrev(tc)) has pending tests.")
            busy!() # set host as busy
            # untested packages for this commit
            un = getuntestedpkg(tc)
            @sync while !isempty(un)
                p = shift!(un)
                ws = pop_worker!() # waits for next available worker
                @async dispatch(tc, p, ws)
            end
            idle!() # set host as idle
            return
        end
    end
end

function pop_worker!(hs::HostState = HOST)
    while isempty(hs.workers)
        @info("No workers available. Will wait...")
        wait(hs.workers_c)
    end
    pop!(hs.workers)
end

function add_worker!(w::WorkerSock, hs::HostState = HOST)
    unshift!(hs.workers, w)
    notify(hs.workers_c)
end

function dispatch(c::Commit, p::PkgRef, ws::WorkerSock)
    try
        serialize(ws.connection, WorkerTaskRequest(p, c, gettail(), HOST.packages))
        wtr = deserialize(ws.connection) :: WorkerTaskResponse # WorkerTaskResponse
        update_result(c, wtr)
        add_worker!(ws)
    catch e
        @warn("Had problems with worker $ws.")
        @err("$e")
    end
end

function update_result(c::Commit, wtr::WorkerTaskResponse)
    if !haskey(HOST.results, c)
        HOST.results[c] = Array(WorkerTaskResponse, 0)
    end
    push!(HOST.results[c], wtr)
end

# TODO: listen to github mentions

# TODO: post results

# TODO: update jpeg for results that readme.md shows
