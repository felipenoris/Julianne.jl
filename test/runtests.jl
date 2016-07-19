
using Julianne
using Base.Test

# Tests for timeout()
event_const_a = 10
event_fun_x(a) = ( sleep(0.1); 100a )
event_fun_xa(a) = 100a
event_fun_y() = ( sleep(0.1); 200 )
event_fun_w(a, b_) = a + b_
event_fun_w2(a, b_) = (sleep(0.1); a + b_)
event_msg = "error_message"

function event_fun_z()
    sleep(0.1)
    throw(ErrorException("error during event_fun_z()"))
end

@test 1 == timeout(1) do
    sleep(0.5)
    return 1
end

@test_throws TimeoutException timeout(1) do
    sleep(2)
    println("hello")
end


@test 100*5 == timeout(1) do
    event_fun_x(5)
end

#=
event_result_r = @timeout 1 event_fun_x(5)
@test event_result_r == 100*5

@test @timeout(1, event_fun_xa(2)) == 200
@test_throws TimeoutException @timeout 0.01 event_fun_z()

@test_throws TimeoutException @timeout 0.01 event_fun_y()
@test_throws TimeoutException @timeout 0.01 event_fun_x(1)
@test_throws ErrorException @timeout 1 event_fun_z() "error"
@test_throws TimeoutException @timeout 0.01 event_fun_z() "error"

@test @timeout(1, event_fun_w(1, event_const_a)) == 11
@test @timeout(1, event_fun_w(1, event_const_a), "error") == 11
@test @timeout(1, event_fun_w2(1, event_const_a)) == event_fun_w(1, event_const_a)
@test_throws TimeoutException @timeout(0.01, event_fun_w2(1, event_const_a))
@test_throws TimeoutException @timeout(0.01, event_fun_w2(1, event_const_a), "error " * "message")
@test_throws TimeoutException @timeout(0.01, event_fun_w2(1, event_const_a), event_msg)

timeout(1) do
    sleep(0.5)
    println("hello")
end

timeout(1) do
    sleep(2)
    println("hello")
end
=#

@test Julianne.sha_abbrev("abcdefasdfasdfasdf") == "abcdefa"

c = Julianne.Commit("abcdjkljskldfajsdfkl", "ajskldfjkalsjdklfjaklsjdf")

@test Julianne.sha_abbrev(c) == "abcdjkl"

# Worker
passing_pkg = Julianne.PkgRef("PassingPkg", "https://github.com/juliannebot/PassingPkg.jl.git")
failing_pkg = Julianne.PkgRef("FailingPkg", "https://github.com/juliannebot/FailingPkg.jl.git")

target = Julianne.Commit("2d973d0a276b644acb18784a4bd7464ec14bdb53", "Fix Dict key completion for qualified names.")
tail = Julianne.Commit("4b0c60f2edff120569d797fcb63c99bfc83e1928", "Fix #17105, @ inferred with kwargs")

request_pass = Julianne.WorkerTaskRequest(passing_pkg, target, tail)
request_fail = Julianne.WorkerTaskRequest(failing_pkg, target, tail)

wi = Julianne.WorkerInfo("Test Suite")

response_pass = Julianne.Worker.testpkg(wi, request_pass)
response_fail = Julianne.Worker.testpkg(wi, request_fail)
