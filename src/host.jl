
# host routines

import Base.IPAddr

rm_if_exists(f) = isfile(f) && rm(f)
istail(c::Commit) = HOST.tail_sha == c.sha
gettail() = Commit(HOST.tail_sha, HOST.commits[end].subject)
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

register_package(pkgname, url="") = push!(HOST.packages, PkgRef(pkgname, url))

#"|- ✔︎✘⎿"

function report_str() # :: String
    tail = gettail()
    r = """
    Current tail is:
    $(tail.sha)-$(tail.subject)
    # of available workers: $(length(HOST.workers))
    """
    for c in HOST.commits
        r = r * "$(sha_abbrev(c))-$(c.subject): $(getstatus(c))\n"
        
        if isdone(c)
            failures, stvec = gettestedpkg(c, [:FAILED, :UNKNOWN])
            if !isempty(failures)
                for i in 1:length(failures)
                    pkg = failures[i]
                    st = stvec[i]
                    r = r * "⎿ $(pkg.name) $(st)\n"
                end
            end
        end

        if istail(c)
            break
        end
    end
    r
end

"""
    getstatus(item) :: Symbol

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
        @info("Server started at $(HOST.ip):$(HOST.port)")
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

function checkhostconfig()
    if isempty(HOST.packages)
        throw(ErrorException("No packages to be tested. Will stop the HOST."))
    end

    if !isdir(HOST.working_dir)
        throw(ErrorException("Working directory not found: $(HOST.working_dir)"))
    end
end

function settail(sha::AbstractString)
    HOST.tail_sha = sha
    @info("Ladies and Gentlemen: our new TAIL is $(sha_abbrev(sha))!")
end
settail(c::Commit) = settail(c.sha)

function gettestedpkg(c::Commit, withstatus::Vector{Symbol} = [:ANY]) # :: Vector{PkgRef}, Vector{Symbol} status
    r = Array(PkgRef,0)
    st = Array(Symbol, 0)
    if haskey(HOST.results, c)
        responses = HOST.results[c]
        for wtr in responses
            if :ANY in withstatus
                push!(r, wtr.request.pkg)
                push!(st, wtr.status)
            else
                if wtr.status in withstatus
                    push!(r, wtr.request.pkg)
                    push!(st, wtr.status)
                end
            end
        end
    end
    return r, st
end
gettestedpkg(c::Commit, withstatus::Symbol) = gettestedpkg(c, [withstatus])

function getuntestedpkg(c::Commit)
    tested, _ = gettestedpkg(c)
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
                    @info("Nothing to do... Let's get some sleep.")
                    @info("Current tail is:\n$(tc.sha)-$(tc.subject)")
                    sleep(HOST.sleep_time)
                    return  # Does nothing until we have new Commits to test
                else
                    continue # goes to next Commit
                end
            else
                if gettail() != tc
                    # YAY! This is our new TAIL!
                    @info("$(sha_abbrev(tc)) is done testing and PASSED.")
                    settail(tc)
                end
                @info("Nothing to do... Let's get some sleep.")
                @info("Current tail is:\n$(tc.sha)-$(tc.subject)")
                sleep(HOST.sleep_time)
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

function pop_worker!()
    while isempty(HOST.workers)
        @info("No workers available. Will wait...")
        wait(HOST.workers_c)
    end
    pop!(HOST.workers)
end

function add_worker!(w::WorkerSock)
    unshift!(HOST.workers, w)
    notify(HOST.workers_c)
end

function dispatch(c::Commit, p::PkgRef, ws::WorkerSock)
    try
        @info("Will dispatch $(sha_abbrev(c)) $(p.name) to $(ws.worker.id)")
        serialize(ws.connection, WorkerTaskRequest(p, c, gettail(), HOST.packages))
        wtr = deserialize(ws.connection) :: WorkerTaskResponse # WorkerTaskResponse
        update_result(c, wtr)
        @info("Got result from $(ws.worker.id): $(sha_abbrev(c)) $(p.name): $(wtr.status)")
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

"""
ip: Host IP address to listen on
port: Host port to listen on
working_dir: working directory to pull Julia's repo on host
sleep_time: sleep time between iterations in seconds
"""
function start(ip::IPAddr, port::Int, webapp_ip, webapp_port, working_dir=pwd(), sleep_time=60*60)
    HOST.ip = ip
    HOST.port = port
    HOST.working_dir = working_dir
    HOST.sleep_time = sleep_time
    HOST.webapp_ip = webapp_ip
    HOST.webapp_port = webapp_port

    # Checks for Host configuration consistency
    checkhostconfig()
    # gen_state_json()
    schedule_listen_task()
    start_webapp()

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
    while true
        pull_julia_repo()
        @info("Starting iteration $i...")
        # dispatch workload
        start_next_test()
        @info("Test iteration $i results:")
        @info(report_str())
        # gen_state_json()
        i += 1
    end
    yield()
end
start(ip::IPAddr, port::Int) = start(ip, port, ip, 80)

#function gen_state_json()
#    io = open(joinpath(HOST.working_dir, "julianne_state.json"), "w")
#    JSON.print(io, HOST)
#    flush(io)
#    close(io)
#end

# TODO: listen to github mentions

# TODO: post results

# TODO: update jpeg for results that readme.md shows
