abstract type TreeIndex{depth} end

Base.length(::TreeIndex{depth}) where {depth} = depth
Base.getindex(index::TreeIndex, i::Int) = (@_propagate_inbounds_meta; index.I[i])
Base.firstindex(index::TreeIndex) = 1
Base.lastindex(index::TreeIndex) = length(index)

TreeIndex(I::Tuple{Vararg{Int}}) = TreeLinearIndex(I)
TreeIndex(I::Tuple{Vararg{CartesianIndex}}) = TreeCartesianIndex(I)
TreeIndex(I...) = TreeIndex(I)

@inline _compute_offsets(::Val{1}, offset_func, x::TreeSize, i::Integer...) = (offset_func(x, i...),)
@inline _compute_offsets(::Val{N}, offset_func, x::TreeSize, i::Integer...) where {N} =
    (offset_func(x, i...), _compute_offsets(Val(N-1), offset_func, Base.tail(x), i...)...)
@inline compute_offsets(offset_func, x::TreeSize, i::Integer...) =
    _compute_offsets(Val(length(x)), offset_func, x, i...)


struct TreeLinearIndex{depth} <: TreeIndex{depth}
    I::NTuple{depth, Int}
end
TreeLinearIndex(I::Int...) = TreeLinearIndex(I)

# offset_linear
@inline function offset_linear(S::TreeSize, i::Vararg{Integer, dim}) where {dim}
    Base._sub2ind(S[1], Tuple(offset_cartesian(S, i...))...)
end
@inline function offset_linear(node::Node, I::Integer...)
    Base._sub2ind(size(node), Tuple(offset_cartesian(node, i...))...)
end

# TreeLinearIndex
@inline TreeLinearIndex(S::TreeSize, i::Integer...) = TreeLinearIndex(compute_offsets(offset_linear, S, i...))
@inline TreeLinearIndex(node::Union{Node, HashNode}, inds::Integer...) = TreeLinearIndex(TreeSize(node), inds...)
function TreeLinearIndex(node::DynamicNode, inds::Integer...)
    t_child = childtype(node)
    tsize_child = TreeSize(t_child)
    i = Base._sub2ind(size(node), block_index(totalsize(tsize_child), inds...)...)
    I = TreeLinearIndex(tsize_child, inds...).I
    TreeLinearIndex(i, I...)
end


struct TreeCartesianIndex{depth, N} <: TreeIndex{depth}
    I::NTuple{depth, CartesianIndex{N}}
end
TreeCartesianIndex(I::CartesianIndex...) = TreeCartesianIndex(I)

# offset_cartesian
@inline function offset_cartesian(S::TreeSize, I::Integer...)
    dims = totalsize(S)
    dims_child = totalsize(Base.tail(S))
    CartesianIndex(block_index(dims_child, (@. rem(I - 1, dims) + 1)...))
end
@inline offset_cartesian(node::Union{Node, HashNode}, I::Integer...) = offset_cartesian(TreeSize(node), I...)
@inline function offset_cartesian(node::DynamicNode, I::Integer...)
    @boundscheck checkbounds(CartesianIndices(totalsize(node)), I...)
    dims_child = totalsize(Base.tail(TreeSize(node)))
    CartesianIndex(block_index(dims_child, I...))
end

# TreeCartesianIndex
@inline TreeCartesianIndex(S::TreeSize, i::Integer...) = TreeCartesianIndex(compute_offsets(offset_cartesian, S, i...))
@inline TreeCartesianIndex(node::Union{Node, HashNode}, inds::Integer...) = TreeCartesianIndex(TreeSize(node), inds...)
function TreeCartesianIndex(node::DynamicNode, inds::Integer...)
    t_child = childtype(node)
    tsize_child = TreeSize(t_child)
    i = CartesianIndex(block_index(totalsize(tsize_child), inds...))
    I = TreeCartesianIndex(tsize_child, inds...).I
    TreeCartesianIndex(i, I...)
end


# totalsize
function totalsize(node::Union{Node, HashNode})
    convert.(Int, totalsize(TreeSize(node)))
end
function totalsize(node::DynamicNode)
    dims = size(node) # don't statically get size to handle the case that rootnode is dynamic node
    dims_child = totalsize(TreeSize(childtype(node)))
    dims .* dims_child
end
