
# Inside module Host

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

"""
    getstatus(c::Commit) :: Symbol

:PASSED, :FAILURE, :UNKNOWN
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
        if :FAILURE ∈ status_set
            return :PENDING_WITH_FAILURE
        elseif :UNKNOWN ∈ status_set
            return :PENDING_WITH_UNKNOWN
        else
            return :PENDING
        end
    else
        # all tests are done
        if :FAILURE ∈ status_set
            return :FAILURE
        elseif :UNKNOWN ∈ status_set
            return :UNKNOWN
        else
            return :PASSED
        end
    end
end

getstatus(wtr::WorkerTaskResponse) = wtr.status
getstatus(sym::Symbol) = sym

ispending(item) = getstatus(item) ∈ [ :UNTESTED, :PENDING, :PENDING_WITH_FAILURE, :PENDING_WITH_UNKNOWN ]
isdone(item) = !ispending(item)
hasfailure(item) = getstatus(item) ∈ [ :FAILURE, :PENDING_WITH_FAILURE ]
isunknown(item) = getstatus(item) ∈ [ :UNKNOWN, :PENDING_WITH_UNKNOWN ]

# Send workload to workers
function start_next_test()
    for tc in HOST.commits
        if isdone(tc)
            # This Commit is done testing
            if hasfailure(tc)
                info("$(sha_abbrev(tc)) is done testing and has FAILURES.")
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
                    info("$(sha_abbrev(tc)) is done testing and PASSED.")
                    settail(tc)
                else
                    info("Nothing to do... Let's get some sleep.")
                    sleep(10)
                end
                return
            end
        else
            # This Commit has pending tests
            info("$(sha_abbrev(tc)) has pending tests.")
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
        info("No workers available. Will wait...")
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
        serialize(ws.connection, WorkerTaskRequest(p, c, gettail()))
        wtr = deserialize(ws.connection) :: WorkerTaskResponse # WorkerTaskResponse
        update_result(c, wtr)
        add_worker!(ws)
    catch e
        warn("Had problems with worker $ws.")
        println("$e")
    end
end

function update_result(c::Commit, wtr::WorkerTaskResponse)
    if !haskey(HOST.results, c)
        HOST.results[c] = Array(WorkerTaskResponse, 0)
    end
    push!(HOST.results[c], wtr)
end
