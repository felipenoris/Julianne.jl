
module Julianne

using GitHub
import Base.IPAddr

include("types.jl")
include("hostconfig.jl")
include("worker.jl")
include("host.jl")
include("api.jl")

end # module
