abstract type TreeIndex{depth} end

@generated function TreeIndex(IndexType, compute_index, ::Powers{p}, i::Int...) where {p}
    pows = p
    exps = Expr[]
    for _ in 1:length(pows)
        push!(exps, :(compute_index(Powers($pows), i...)))
        pows = Base.tail(pows)
    end
    quote
        @_inline_meta
        IndexType(tuple($(exps...)))
    end
end


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

@inline TreeLinearIndex(P::Powers, i::Int...) = TreeIndex(TreeLinearIndex, compute_linear, P, i...)


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

@inline TreeCartesianIndex(P::Powers, i::Int...) = TreeIndex(TreeCartesianIndex, compute_cartesian, P, i...)
