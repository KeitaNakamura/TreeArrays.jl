struct LeafNode{T, N, p} <: AbstractNode{T, N, p}
    data::MaskedArray{T, N}
    LeafNode{T, N, p}(data) where {T, N, p} = new(data)
    LeafNode{T, N, p}(::Nothing) where {T, N, p} = new()
end

function LeafNode{T, N, p}() where {T, N, p}
    dims = size(LeafNode{T, N, p})
    data = MaskedArray{T}(undef, dims)
    LeafNode{T, N, p}(data)
end

@pure childtype(::Type{<: LeafNode}) = nothing
@pure leaftype(T::Type{<: LeafNode}) = T
@pure leafeltype(::Type{<: LeafNode{T}}) where {T} = T

Base.size(x::LeafNode) = size(typeof(x))
Base.IndexStyle(::Type{<: LeafNode}) = IndexLinear()

@inline function Base.getindex(x::LeafNode, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i]
end

@inline function Base.setindex!(x::LeafNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i] = v
    x
end

@inline function deactivate!(x::LeafNode)
    isnull(x) || fillmask!(x, false)
    x
end

allocate!(x::LeafNode, i) = x
cleanup!(x::LeafNode) = x

nleaves(x::LeafNode) = countmask(x.data)
