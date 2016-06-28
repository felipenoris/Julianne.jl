
# Worker routines

module Worker

import ..PkgRef
import ..Commit
import ..sha_abbrev
import ..WorkerInfo
import ..WorkerTask

const SRC_DIR = dirname(@__FILE__)

# updates HEAD and TARGET files used by the Dockerfile
function refresh_docker_head_marker(head_sha::AbstractString)
	try
		head_filepath = joinpath(SRC_DIR, "docker", "HEAD")
		if isfile(head_filepath)
			rm(head_filepath)
		end

		head_file = open(head_filepath, "w")
		write(head_file, head_sha)
		close(head_file)
	catch e
		warn("error $e")
	end
end

# updates HEAD and TARGET files used by the Dockerfile
function refresh_docker_target_marker(target_sha::AbstractString)
	try
		target_filepath = joinpath(SRC_DIR, "docker", "TARGET")
		if isfile(target_filepath)
			rm(target_filepath)
		end

		target_file = open(target_filepath, "w")
		write(target_file, target)
		close(target_file)
	catch e
		warn("error $e")
	end
end

# builds just the head
function build_head()
	try
		run(`docker build -t julia:head -f $(joinpath(SRC_DIR, "docker", "Dockerfile.head")) $(joinpath(SRC_DIR, "docker"))`)
	catch e
		warn("error $e")
	end
end

# builds the target commit for testing
function build_target(pkg::PkgRef)
	try
		build_head()
		run(`docker build -t julia:$(sha_abbrev(pkg)) -f $(joinpath(SRC_DIR, "docker", "Dockerfile.target")) $(joinpath(SRC_DIR, "docker"))`)
	catch e
		warn("error $e")
	end
end

#function testpkg(pkg::PkgRef)
#	try
#		build_target(pkg)
#		Pkg.clone(pkg.url)
#		Pkg.test(pkg.name)
#		# TODO: record result of versioninfo(io)
#	catch e
#		# TODO : catch STDERR messages, see redirect_stdout, redirect_stderr
#		WorkerTask(pkg, false, "$e")
#	end
#
#	return WorkerTask(pkg, true, "")
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
    #   	pkgref = deserialize(c)    # <--- Block wait for a request
    #   	println("going to test $(pkgref.name)")
    #   	result = testpkg(pkgref)
    #   	println("Received request for $(pkgref.name). Response $result.")
    #   	serialize(c, result)        # <--- send back response
    #   	println("Result was sent to Host!")
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
