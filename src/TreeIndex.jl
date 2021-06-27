abstract type TreeIndex{depth} end

@generated function compute_offsets(offset_func, ::Powers{p}, i::Int...) where {p}
    P = Powers(p)
    exps = Expr[]
    for _ in 1:length(p)
        push!(exps, :(offset_func($P, i...)))
        P = Base.tail(P)
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

Base.length(::TreeLinearIndex{depth}) where {depth} = depth
Base.getindex(index::TreeLinearIndex, i::Int) = (@_propagate_inbounds_meta; index.I[i])

@inline function offset_linear(P::Powers{pows}, i::Vararg{Int, dim}) where {pows, dim}
    sub2ind(P, Tuple(offset_cartesian(P, i...))...)
end

@inline TreeLinearIndex(P::Powers, i::Int...) =
    TreeLinearIndex(compute_offsets(offset_linear, P, i...))


struct TreeCartesianIndex{depth, N} <: TreeIndex{depth}
    I::NTuple{depth, CartesianIndex{N}}
end
TreeCartesianIndex(I::CartesianIndex...) = TreeCartesianIndex(I)

Base.length(::TreeCartesianIndex{depth}) where {depth} = depth
Base.getindex(index::TreeCartesianIndex, i::Int) = (@_propagate_inbounds_meta; index.I[i])

@inline function offset_cartesian(P::Powers, I::Int...)
    p = sum(P)
    p_child = sum(Base.tail(P))
    CartesianIndex(@. ((I - 1) & $(1 << p - 1)) >> p_child + 1)
end

@inline TreeCartesianIndex(P::Powers, i::Int...) =
    TreeCartesianIndex(compute_offsets(offset_cartesian, P, i...))
