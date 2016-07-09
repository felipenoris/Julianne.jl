
import Base: notify_error

type TimeoutException <: Exception
    msg::AbstractString

    TimeoutException() = new("")
    TimeoutException(msg) = new(msg)
end

"""
    @timeout(t, ex, [msg])

Set a timeout of `t` seconds on the execution time of expression `ex`.
Throws `TimeoutException` with optional error message `msg`
if the timeout is triggered.

Be aware that the exception raised by the timeout will not abort
the evaluation of `ex`.
"""
macro timeout(timeout_s, ex, msg="")
    if isa(msg, Expr) || isa(msg, Symbol)
        # message is an expression needing evaluating
        msg = :(Main.Base.string($(esc(msg))))
    elseif msg == ""
        msg = string(ex)
    end

    quote
        let
            wt = Condition()
            timeout_occurred = true

            @schedule try
                r = $(esc(ex))
                timeout_occurred = false
                notify(wt, r)
            catch e
                notify_error(wt, e)
            end

            @schedule ( sleep($(esc(timeout_s))); notify(wt) )

            result = wait(wt)
            timeout_occurred && throw(TimeoutException($msg))
            result
        end
    end
end

function timeout(f, timeout_s, msg="", args...)
    wt = Condition()
    timeout_ocurred = true

    @schedule try
        r = f(args...)
        timeout_ocurred = false
        notify(wt, r)
    catch e
        notify(wt, e)
    end

    @schedule ( sleep(timeout_s); notify(wt) )

    result = wait(wt)
    timeout_ocurred && throw(TimeoutException(msg))
    result
end
