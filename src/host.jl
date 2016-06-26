
# host routines

module Host

import ..HostState
import ..TestResult
import ..Worker
import ..PkgRef
import ..Commit
import ..Worker
import ..WorkerSock
import ..WorkerInfo
import ..HOST

rm_if_exists(f) = isfile(f) && rm(f)

# Get's the latest julia's repo and updates list of commits.
function pull_julia_repo()
	print("Updating julia repo...")
	
	const HOME_DIR = HOST.working_dir

	if !isdir(HOME_DIR)
		throw(ErrorException("home dir not found: $HOME_DIR"))
	end

	cd(HOME_DIR)

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

	empty!(HOST.commit_list)

	while c != HOST.head_sha
		c = chomp(readline(file_c))
		s = chomp(readline(file_s))

		println("$c : $s")
		push!(HOST.commit_list, Commit(c, s))
	end

	close(file_c)
	close(file_s)
	rm_if_exists("commits.txt")
	rm_if_exists("subjects.txt")
	println(" done!")
end

# listens for connections on background
function schedule_listen_task()
	@schedule begin
    	srvr = listen(HOST.port)
    	while true
    		socket = accept(srvr)
        	try
        		handshake(socket)
        	catch e
        		println("Couldn't accept connection: $e")
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
	push!(HOST.workersocks, WorkerSock(worker, socket))
	println("New worker connected! Go for it, '$worker.id' !")
end

workerscount() = length(HOST.workersocks)

function start(ip, port)
	HOST.ip = ip
	HOST.port = port
	start()
end

function start()

	schedule_listen_task()

	# starting local workers
	sleep(0.2) # let's go slow...
	if nprocs() == 1
		println("No local workers will be created. Use addprocs(n) before running `start_host()` to allow for local workers.")
	else
		for ww in procs()
			ww == 1 && continue
			@spawnat ww Worker.start("Local worker $ww", HOST.ip, HOST.port)
		end
	end

	# main loop for server work
	while true
		
		while workerscount() == 0
			println("No workers registered. Will wait...")
			sleep(5)
		end

		pull_julia_repo()

		# dispatch workload for workers
		#i = dispatch()

		show(HOST.results_dict)
		sleep(120) # seconds
	end
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
    	# 		for all commits in a circular fashion
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

function update_result(r::TestResult)
	HOST.results_dict[r.ref.commit] = [r]
end

# TODO: listen to github mentions

# TODO: post results

# TODO: update jpeg for results that readme.md shows

end # module
