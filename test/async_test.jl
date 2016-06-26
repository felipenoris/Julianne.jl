
tc = Condition()
@schedule (sleep(5); notify(tc))
response_channel = Channel()

@async begin
		try
            sleep(10)
            println("Worker: value is ready. Will write response_channel.")
            put!(response_channel, "value")
        catch e
            print("Error $e")
            put!(response_channel, :ERROR)
        finally
        	println("Worker: My work is done! Will notify...")
            notify(tc)
        end
end

if !isready(response_channel)
	println("Host: Response not ready. Will wait for a notify.")
	wait(tc)
	println("Host: Got notified!")
end

if isready(response_channel)
	# consume result
	resp = take!(response_channel)
	println("Host: Result was: $resp.")
else
	println("Host: Response was not ready. There was a timeout...")
end
