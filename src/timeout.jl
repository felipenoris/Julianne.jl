
type TimeoutException <: Exception
    msg::AbstractString

    TimeoutException() = new("")
    TimeoutException(msg) = new(msg)
end

"""
    timeout(f, timeout_s, [msg], [args...])

f must be a callable object.
"""
function timeout(f, timeout_s, msg="", args...)
    wt = Condition()
    timeout_ocurred = true

    @schedule try
        r = f(args...)
        timeout_ocurred = false
        notify(wt, r)
    catch e
        notify_error(wt, e)
    end

    @schedule ( sleep(timeout_s); notify(wt) )

    result = wait(wt)
    timeout_ocurred && throw(TimeoutException(msg))
    result
end
