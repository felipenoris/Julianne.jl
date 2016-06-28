
function poll()
    wt = Condition()
    
    result = 0

    @schedule (result =  ( sleep(rand()*10) ; 100 ) ; notify(wt) )
    @schedule (sleep(110.1); notify(wt))

    wait(wt)
    return result
end

x = poll()
