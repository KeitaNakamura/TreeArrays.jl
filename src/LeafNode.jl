struct LeafNode{T, N, pow} <: AbstractNode{T, N, pow}
    data::MaskedArray{T, N}
    prev::Pointer{LeafNode{T, N, pow}}
    next::Pointer{LeafNode{T, N, pow}}
end

function LeafNode{T, N, pow}() where {T, N, pow}
    @assert isbitstype(T)
    dims = size(LeafNode{T, N, pow})
    data = MaskedArray{T}(undef, dims)
    prev = Pointer{LeafNode{T, N, pow}}(nothing)
    next = Pointer{LeafNode{T, N, pow}}(nothing)
    LeafNode{T, N, pow}(data, prev, next)
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

allocate!(x::LeafNode, i...) = x
cleanup!(x::LeafNode) = x
