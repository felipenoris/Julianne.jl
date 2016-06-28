
using Base.Test

x(a) = ( sleep(0.5); 100a )
y() = ( sleep(0.5); 200 )

function z()
    sleep(0.5)
    throw(ErrorException("error during z()"))
end

xa(a) = 100a

@test @set_timeout 1 x(5) == 100*5

r = @set_timeout 1 x(5)
@test r == 100*5

@test @set_timeout 1 xa(2) == 200
@test_throws TimeoutException @set_timeout 0.1 z()

@test_throws TimeoutException @set_timeout 0.1 y()
@test_throws TimeoutException @set_timeout 0.1 x(1)
@test_throws ErrorException @set_timeout 1 z() "msg"
@test_throws TimeoutException @set_timeout 0.1 z() "msg"
