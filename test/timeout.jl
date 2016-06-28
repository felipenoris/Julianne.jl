
import Base: notify_error

type TimeoutException <: Exception
    msg::AbstractString

    TimeoutException() = new("")
    TimeoutException(msg) = new(msg)
end

macro set_timeout(timeout_s, exp, msgs...)
    t_ = eval(timeout_s)

    msg = isempty(msgs) ? exp : msgs[1]
    if !isempty(msgs) && (isa(msg, Expr) || isa(msg, Symbol))
        # message is an expression needing evaluating
        msg = :(Main.Base.string($(esc(msg))))
    elseif isdefined(Main, :Base) && isdefined(Main.Base, :string)
        msg = Main.Base.string(msg)
    else
        # string() might not be defined during bootstrap
        msg = :(Main.Base.string($(Expr(:quote,msg))))
    end

    quote
        let
            wt = Condition()
            timeout_occurred = true

            @schedule ( try r = $(esc(exp)); timeout_occurred = false; notify(wt, r); catch e; notify_error(wt, e); end )
            @schedule ( sleep($t_); notify(wt) )

            result = wait(wt)
            timeout_occurred && throw(TimeoutException($msg))

            result
            end
    end
end
