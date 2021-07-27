module TreeArrays

using Base: @_inline_meta, @_propagate_inbounds_meta, @pure

using StaticArrays
using Coordinates

export
    TreeSize,
    TreeIndex,
    TreeLinearIndex,
    TreeCartesianIndex,
    LeafNode,
    Node,
    DynamicNode,
    DynamicHashNode,
    HashNode,
    TreeView,
    TreeArray,
    ContinuousView,
    SpotView,
    eachleaf!,
    nleaves

const THREADS_THRESHOLD = 1 << 13

include("utils.jl")
include("MaskedArray.jl")
include("PropertyArray.jl")
include("AbstractNode.jl")
include("LeafNode.jl")
include("Node.jl")
include("HashNode.jl")
include("TreeIndex.jl")
include("TreeView.jl")
include("TreeArray.jl")
include("ContinuousView.jl")
include("iterators.jl")
include("show.jl")

end # module
