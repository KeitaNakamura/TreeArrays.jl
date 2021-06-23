module TreeArrays

using Base: @_inline_meta, @_propagate_inbounds_meta, @pure

using StaticArrays

export
    Powers,
    TreeLinearIndex,
    TreeCartesianIndex,
    LeafNode,
    Node,
    TreeArray,
    FlatView

include("AbstractNode.jl")
include("TreeIndex.jl")
include("LeafNode.jl")
include("Node.jl")
include("TreeArray.jl")
include("FlatView.jl")

end # module
