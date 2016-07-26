
module Julianne

using GitHub
using Logging
import Base.IPAddr
import Base: notify_error, hash, ==

export TimeoutException, timeout

# Set logging
@Logging.configure(filename="julianne_host.log", level=INFO)

include("timeout.jl")
include("types.jl")
include("host.jl")
include("hostconfig.jl")
include("worker.jl")
include("api.jl")

end # module
