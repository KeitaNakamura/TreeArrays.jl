struct LeafNode{T, N, pow} <: AbstractNode{T, N, pow}
    data::Array{T, N}
    mask::BitArray{N}
    prev::Pointer{LeafNode{T, N, pow}}
    next::Pointer{LeafNode{T, N, pow}}
end

function LeafNode{T, N, pow}() where {T, N, pow}
    @assert isbitstype(T)
    dims = size(LeafNode{T, N, pow})
    data = Array{T}(undef, dims)
    prev = Pointer{LeafNode{T, N, pow}}(nothing)
    next = Pointer{LeafNode{T, N, pow}}(nothing)
    LeafNode{T, N, pow}(data, falses(dims), prev, next)
end

@pure childtype(::Type{<: LeafNode}) = nothing
@pure leaftype(T::Type{<: LeafNode}) = T
@pure leafeltype(::Type{<: LeafNode{T}}) where {T} = T

Base.IndexStyle(::Type{<: LeafNode}) = IndexLinear()

@inline function Base.getindex(x::LeafNode, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        checkmask(x, i)
        x.data[i]
    end
end

@inline function Base.setindex!(x::LeafNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        x.data[i] = v
        x.mask[i] = true
    end
    x
end

@inline function Base.setindex!(x::LeafNode, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.mask[i] = false
    x
end

allocate!(x::LeafNode, i...) = x

cleanup!(x::LeafNode) = x
