
response_channel = Channel()
tc = Condition()
@schedule (sleep(15); notify(tc))

function create_worker(id::Int)
    @schedule begin
        try                     # <---- start all remote requests
            println("Worker $id: going to sleep...")
            sleep(5 + id)
            println("Worker $id: just woke up")
            r = 0.0
            for i in 1:10
                r = rand(1000)
                r = exp( log(r.^2) + 1 )
            end

            println("Worker $id: value is ready: $(r[1]). Will write response_channel.")
            put!(response_channel, "worker $id , value $(r[1])")
        catch e
            print("Error on worker $id: $e")
            put!(response_channel, :ERROR)
        finally
            println("Worker $id: My work is done! Will notify...")
            notify(tc)
        end
    end

end

for i in 1:5
    println("Launching worker $i")
    create_worker(i)
end

@async begin
    println("Launching Host consuming job...")
    while true
        !isready(response_channel) && wait(tc)
        
        if !isready(response_channel)
            println("Host: Was notified but channel isn't ready. This is a timeout! Shutting down...")
            break
        end

        resp = take!(response_channel)
        println("Host: Result was: '$resp.'")
    end
end

println("#### End! ####")