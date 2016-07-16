
# Inside module Host

#=
type HostState
    ip::IPAddr
    port::Int
    working_dir::AbstractString
    lastupdate::DateTime
    commits::Vector{Commit} # Ordered list of commits
    results::Dict{Commit, Vector{WorkerTaskResponse}} # maps Commit to test status. If it's not there, hasn't been dispached yet for testing. The vector allows for one test for each package.
    workersocks::Vector{WorkerSock} # registered workers
    packages::Vector{PkgRef}
    tail_sha::AbstractString

    HostState(ip, port, working_dir) = new(ip, port, working_dir, now(), Array(AbstractString, 0), Dict{AbstractString, Vector{WorkerTaskResponse}}(), Array(WorkerSock, 0), Array(PkgRef, 0), "")
end
=#

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
function dispatch()
    for tc in HOST.commits
        if isdone(tc)
            # This Commit is done testing
            if hasfailure(tc)
                # TODO: This may do bisection in the future...
                # For now, go test the next Commit in list until we reach the TAIL
                if istail(tc)
                    return  # Does nothing until we have new Commits to test
                else
                    continue # goes to next Commit
                end
            else
                # YAY! This is our new TAIL!
                settail(tc)
                return
            end
        else
            # This Commit has pending tests
            # Let's check if there's some idle worker
            println("TODO: should dispatch a test for $tc...")
            return
        end
    end
end

function update_result(r::WorkerTaskResponse)
    HOST.results[r.ref.commit] = [r]
end

#=
function dispatch()

    tc = Condition()
    @schedule (sleep(120); notify(tc))

    response_channel = Channel()

    nconn = 0
    conn2 = copy(HOST.connections)

    for c in conn2

        # TODO: calculate execution pipeline, for now tests only the first package
        #       for all commits in a circular fashion
        pkgref = copy(STATE.packages[1])
        pkgref.commit = STATE.commit_list[1]

        nconn += 1 
        @async try                     # <---- start all remote requests
            serialize(c, pkgref)
            put!(response_channel, deserialize(c))
        catch e
            put!(response_channel, :ERROR)
            delete!(CONNECTIONS, c)
        finally
            notify(tc)
        end

        tt = div(tt+1, length(STATE.commit_list))
    end

    # wait for all responses or the timeout
    for i in 1:nconn
        !isready(response_channel) && wait(tc)   # Block wait for a pending response or a timeout
        !isready(response_channel) && break      # Still not ready, indicates a timeout

        resp = take!(response_channel)
        if resp != :ERROR
            update_result(resp)
        end
    end

    return tt

    # TODO: update test status with results
end
=#
