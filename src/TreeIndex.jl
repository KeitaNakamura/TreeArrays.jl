abstract type TreeIndex{depth} end

struct TreeLinearIndex{depth} <: TreeIndex{depth}
    I::NTuple{depth, Int}
end

Base.length(::TreeLinearIndex{depth}) where {depth} = depth
Base.getindex(index::TreeLinearIndex, i::Int) = (@_propagate_inbounds_meta; index.I[i])

@generated function compute_linear(::Powers{pows}, i::Vararg{Int, dim}) where {pows, dim}
    P = Powers(pows)
    ttl_p = sum(P)
    ttl_cp = sum(Base.tail(P))
    exps = map(1:dim) do d
        :((((i[$d] - 1) & $(1 << ttl_p - 1)) >> $ttl_cp) << $(sum(Int[P[1] for _ in 1:d-1])))
    end
    quote
        @_inline_meta
        $(Expr(:call, :+, exps...)) + 1
    end
end

compute_treelinearindex(P::Powers, i::Int...) = (compute_linear(P, i...), compute_treelinearindex(Base.tail(P), i...)...)
compute_treelinearindex(P::Powers{()}, i::Int...) = ()
TreeLinearIndex(P::Powers, i::Int...) = TreeLinearIndex(compute_treelinearindex(P, i...))


struct TreeCartesianIndex{depth, N} <: TreeIndex{depth}
    I::NTuple{depth, CartesianIndex{N}}
end

Base.length(::TreeCartesianIndex{depth}) where {depth} = depth
Base.getindex(index::TreeCartesianIndex, i::Int) = (@_propagate_inbounds_meta; index.I[i])

@generated function compute_cartesian(::Powers{pows}, i::Vararg{Int, dim}) where {pows, dim}
    P = Powers(pows)
    ttl_p = sum(P)
    ttl_cp = sum(Base.tail(P))
    exps = map(1:dim) do d
        :((((i[$d] - 1) & $(1 << ttl_p - 1)) >> $ttl_cp))
    end
    quote
        @_inline_meta
        CartesianIndex(tuple($(exps...)) .+ 1)
    end
end

compute_treecartesianindex(P::Powers, i::Int...) = (compute_cartesian(P, i...), compute_treecartesianindex(Base.tail(P), i...)...)
compute_treecartesianindex(P::Powers{()}, i::Int...) = ()
TreeCartesianIndex(P::Powers, i::Int...) = TreeCartesianIndex(compute_treecartesianindex(P, i...))
