abstract type TreeIndex{depth} end

Base.length(::TreeIndex{depth}) where {depth} = depth
Base.getindex(index::TreeIndex, i::Int) = (@_propagate_inbounds_meta; index.I[i])
Base.firstindex(index::TreeIndex) = 1
Base.lastindex(index::TreeIndex) = length(index)

TreeIndex(I::Tuple{Vararg{Int}}) = TreeLinearIndex(I)
TreeIndex(I::Tuple{Vararg{CartesianIndex}}) = TreeCartesianIndex(I)
TreeIndex(I...) = TreeIndex(I)

@generated function compute_offsets(offset_func, ::TreeSize{s}, i::Integer...) where {s}
    S = TreeSize(s)
    exps = Expr[]
    for _ in 1:length(S)
        push!(exps, :(offset_func($S, i...)))
        S = Base.tail(S)
    end
    quote
        @_inline_meta
        tuple($(exps...))
    end
end


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
