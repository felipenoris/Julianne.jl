
# Worker routines

module Worker


import ..PkgRef
import ..Commit
import ..sha_abbrev
import ..HOST

const SRC_DIR = dirname(@__FILE__)

# updates HEAD and TARGET files used by the Dockerfile
function refresh_docker_markers(head, target)
	try
		# HEAD
		head_filepath = joinpath(SRC_DIR, "docker", "HEAD")
		if isfile(head_filepath)
			rm(head_filepath)
		end

		head_file = open(head_filepath, "w")
		write(head_file, head)
		close(head_file)

		# TARGET
		target_filepath = joinpath(SRC_DIR, "docker", "TARGET")
		if isfile(target_filepath)
			rm(target_filepath)
		end

		target_file = open(target_filepath, "w")
		write(target_file, target)
		close(target_file)
	catch e
		print("error $e")
	end
end

# builds just the head
function build_head()
	try
		run(`docker build -t julia:head -f $(joinpath(SRC_DIR, "docker", "Dockerfile.head")) $(joinpath(SRC_DIR, "docker"))`)
	catch e
		print("error $e")
	end
end

# builds the target commit for testing
function build_target(pkg::PkgRef)
	try
		build_head()
		run(`docker build -t julia:$(sha_abbrev(pkg)) -f $(joinpath(SRC_DIR, "docker", "Dockerfile.target")) $(joinpath(SRC_DIR, "docker"))`)
	catch e
		print("error $e")
	end
end

function testpkg(pkg::PkgRef)
	try
		build_target(pkg)
		Pkg.clone(pkg.url)
		Pkg.test(pkg.name)
		# TODO: record result of versioninfo(io)
	catch e
		# TODO : catch STDERR messages, see redirect_stdout, redirect_stderr
		TestResult(pkg, false, "$e")
	end

	return TestResult(pkg, true, "")
end

# connects to host and waits for the workload
function register()
	println("registering...")

	@schedule begin
		c = connect(HOST.ip, HOST.port)
    	while true
        	pkgref = deserialize(c)    # <--- Block wait for a request
        	println("going to test $(pkgref.name)")
        	result = testpkg(pkgref)
        	println("Received request for $(pkgref.name). Response $result.")
        	serialize(c, result)        # <--- send back response
    	end
	end
end

end # module
