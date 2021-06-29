struct LeafNode{T, N, pow} <: AbstractNode{T, N, pow}
    data::MaskedArray{T, N}
    LeafNode{T, N, pow}(data) where {T, N, pow} = new(data)
    LeafNode{T, N, pow}(::Nothing) where {T, N, pow} = new()
end

function LeafNode{T, N, pow}() where {T, N, pow}
    dims = size(LeafNode{T, N, pow})
    data = MaskedArray{T}(undef, dims)
    LeafNode{T, N, pow}(data)
end

@pure childtype(::Type{<: LeafNode}) = nothing
@pure leaftype(T::Type{<: LeafNode}) = T
@pure leafeltype(::Type{<: LeafNode{T}}) where {T} = T

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

@inline function unsafe_getindex(x::LeafNode, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_getindex(x.data, i)
end

@inline function unsafe_setindex!(x::LeafNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_setindex!(x.data, v, i)
end

@inline function deactivate!(x::LeafNode)
    isnull(x) || fillmask!(x, false)
    x
end

allocate!(x::LeafNode, i...) = x
cleanup!(x::LeafNode) = x
