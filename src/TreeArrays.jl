module TreeArrays

using Base: @_inline_meta, @_propagate_inbounds_meta, @pure

using StaticArrays, Coordinates

export
    Powers,
    TreeLinearIndex,
    TreeCartesianIndex,
    LeafNode,
    Node,
    TreeView,
    TreeIndex,
    FlatView,
    leaves

include("utils.jl")
include("MaskedArray.jl")
include("AbstractNode.jl")
include("TreeIndex.jl")
include("LeafNode.jl")
include("Node.jl")
include("TreeView.jl")
include("FlatView.jl")
include("iterators.jl")
include("show.jl")

end # module
