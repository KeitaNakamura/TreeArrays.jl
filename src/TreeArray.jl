struct TreeArray{T, N, NT <: AbstractNode{<: Any, N}} <: AbstractArray{T, N}
    node::NT
    dims::NTuple{N, Int}
end

function TreeArray(node::AbstractNode{<: Any, N}) where {N}
    n = 1 << sum(Powers(node))
    T = leafeltype(node)
    TreeArray{T, N, typeof(node)}(node, ntuple(d -> n, Val(N)))
end

function TreeArray(node::AbstractNode, dims::NTuple{N, Int}) where {N}
    maxlen = 1 << sum(Powers(node))
    @assert all(≤(maxlen), dims)
    T = leafeltype(node)
    TreeArray{T, N, typeof(node)}(node, dims)
end

Base.size(x::TreeArray) = x.dims

function Base.isassigned(x::TreeArray, i::Int...)
    try
        x[i...]
    catch
        return false
    end
    true
end

TreeLinearIndex(x::TreeArray{<: Any, N}, I::Vararg{Int, N}) where {N} = TreeLinearIndex(Powers(x.node), I...)
TreeCartesianIndex(x::TreeArray{<: Any, N}, I::Vararg{Int, N}) where {N} = TreeCartesianIndex(Powers(x.node), I...)

function Base.getindex(x::TreeArray{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds x[index]
end

function Base.setindex!(x::TreeArray{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds x[index] = v
end

@generated function Base.getindex(x::TreeArray, I::TreeIndex{depth}) where {depth}
    exps = map(1:depth) do i
        quote
            index = I[$i]
            allocate!(node, index)
            node = node[index]
        end
    end
    quote
        @_inline_meta
        @_propagate_inbounds_meta
        node = x.node
        $(exps...)
    end
end

@generated function Base.setindex!(x::TreeArray, v, I::TreeIndex{depth}) where {depth}
    exps = map(1:depth) do i
        quote
            index = I[$i]
            allocate!(node, index)
            $(i == depth ? :(node[index] = v) : :(node = node[index]))
        end
    end
    quote
        @_inline_meta
        @_propagate_inbounds_meta
        node = x.node
        $(exps...)
    end
end
