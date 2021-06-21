module TreeArrays

using Base: @_inline_meta, @_propagate_inbounds_meta, @pure

using StaticArrays

export
    Powers,
    TreeIndex,
    Leaf,
    Node,
    TreeArray

include("AbstractNode.jl")
include("Leaf.jl")
include("Node.jl")
include("TreeArray.jl")

end # module
