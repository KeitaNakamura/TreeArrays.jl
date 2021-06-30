module TreeArrays

using Base: @_inline_meta, @_propagate_inbounds_meta, @pure

using StaticArrays
using Coordinates

export
    Powers,
    TreeIndex,
    TreeLinearIndex,
    TreeCartesianIndex,
    LeafNode,
    Node,
    TreeView,
    ContinuousView,
    SpotView,
    eachleaf!,
    nleaves

const THREADS_THRESHOLD = 1 << 13

include("utils.jl")
include("MaskedArray.jl")
include("AbstractNode.jl")
include("TreeIndex.jl")
include("LeafNode.jl")
include("Node.jl")
include("TreeView.jl")
include("ContinuousView.jl")
include("iterators.jl")
include("show.jl")

end # module
