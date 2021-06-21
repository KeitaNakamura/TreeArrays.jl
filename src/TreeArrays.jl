module TreeArrays

using Base: @_propagate_inbounds_meta, @pure

using StaticArrays

export
    TreeIndex,
    TreeSize,
    Leaf,
    Node

include("BitMask.jl")
include("AbstractNode.jl")
include("TreeIndex.jl")
include("Leaf.jl")
include("Node.jl")

end # module
