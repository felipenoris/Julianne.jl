
let 
	wt = Condition()
	result = 0
	@schedule (result = ( sleep(0.1) ; 100 ) ; notify(wt) )
	wait(wt)
	println("$result")
end

function poll()
	wt = Condition()
	result = 0
	@schedule (result = ( sleep(0.1) ; 100 ) ; notify(wt) )
	wait(wt)
	return result
end

x = poll()
println("$x")
