
# host routines

module Host

import ..HostState
import ..TestResult
import ..TestWorker
import ..PkgStatus
import ..PkgRef
import ..Commit
import ..Worker.register
import ..HOST

const STATE = HostState()

# List of packages to be tested
push!(STATE.packages, PkgRef("PassingPkg", "https://github.com/juliannebot/PassingPkg.jl.git"))
push!(STATE.packages, PkgRef("FailingPkg", "https://github.com/juliannebot/FailingPkg.jl.git"))

# Set's head commit
STATE.head_sha = "e62b204599418164e8a3cbcf88dc6ff556c3ad83"

# Get's the latest julia's repo and updates list of commits.
function refresh()
	if !isdir(HOME_DIR)
		throw(ErrorException("home dir not found: $HOME_DIR"))
	end

	cd(HOME_DIR)

	if !isdir("julia")
		# clone repo
		run(`git clone https://github.com/JuliaLang/julia.git`)
	end

	isfile("commits.txt") && rm("commits.txt")
	cd("julia")
	run(`git pull`)
	run(pipeline(`git log --pretty=format:%H`, joinpath("..", "commits.txt")))
	run(pipeline(`git log --pretty=format:%s`, joinpath("..", "subjects.txt")))
	cd("..")

	file_c = open("commits.txt")
	file_s = open("subjects.txt")
	c = ""

	empty!(STATE.commit_list)

	while c != head_sha()
		c = chomp(readline(file_c))
		s = chomp(readline(file_s))

		println("$c : $s")
		push!(STATE.commit_list, Commit(c, s))
	end

	close(file_c)
	close(file_s)
end

function main()

	const connections=Set()

	# listens for connections
	@schedule begin
    	srvr = listen(HOST.port)
    	while true
        	sock = accept(srvr)
        	push!(connections, sock)
    	end
	end

	# starts local workers
	for ww in 1:4
		@schedule begin
			register()
		end
	end

	# main loop for server work
	i = 1
	while true
		refresh()

		# dispatch workload for workers
		i = dispatch(i, connections)

		show(STATE)
		sleep(120) # seconds
	end
end

function dispatch(t, connections)

	tt = t

    # This function will wait for a maximum of 120 seconds for remote workers to return
    tc = Condition()
    @schedule (sleep(120); notify(tc))

    response_channel = Channel()

    nconn = 0
    conn2 = copy(connections)

    for c in conn2

    	# TODO: calculate execution pipeline, for now tests only the first package
    	# 		for all commits in a circular fashion
    	pkgref = copy(STATE.packages[1])
    	pkgref.commit = STATE.commit_list[tt]

        nconn += 1 
        @async try                     # <---- start all remote requests
            serialize(c, pkgref)
            put!(response_channel, deserialize(c))
        catch e
            put!(response_channel, :ERROR)
            delete!(connections, c)
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

function update_result(r::TestResult)
	STATE.commit_dict[r.ref.commit] = [ PkgStatus(r.ref, "Tested...", v"0.0.1") ]
end

# TODO: listen to github mentions

# TODO: post results

# TODO: update jpeg for results that readme.md shows

end # module
