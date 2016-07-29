
module Julianne

using GitHub
using Logging
using JSON
import Base.IPAddr
import Base: notify_error, hash, ==

export TimeoutException, timeout

# Set logging
@Logging.configure(filename="julianne.log", level=INFO)

include("timeout.jl")
include("types.jl")

const HOST = HostState()

include("host.jl")
include("hostconfig.jl")
include("worker.jl")
include("api.jl")

end # module
