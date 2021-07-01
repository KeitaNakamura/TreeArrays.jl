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

@inline function offset_linear(S::TreeSize, i::Vararg{Integer, dim}) where {dim}
    Base._sub2ind(S[1], Tuple(offset_cartesian(S, i...))...)
end

@inline TreeLinearIndex(S::TreeSize, i::Integer...) =
    TreeLinearIndex(compute_offsets(offset_linear, S, i...))


struct TreeCartesianIndex{depth, N} <: TreeIndex{depth}
    I::NTuple{depth, CartesianIndex{N}}
end
TreeCartesianIndex(I::CartesianIndex...) = TreeCartesianIndex(I)

@inline function offset_cartesian(S::TreeSize, I::Integer...)
    dims = totalsize(S)
    dims_child = totalsize(Base.tail(S))
    CartesianIndex(@. div(rem(I - 1, dims), dims_child) + 1)
end

@inline TreeCartesianIndex(S::TreeSize, i::Integer...) =
    TreeCartesianIndex(compute_offsets(offset_cartesian, S, i...))
