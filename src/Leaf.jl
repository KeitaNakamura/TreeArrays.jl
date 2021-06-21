struct Leaf{T, L} <: AbstractNode{T, L}
    data::MVector{L, T}
    mask::BitVector
    prev::Pointer{Leaf{T, L}}
    next::Pointer{Leaf{T, L}}
end

Leaf{T, L}(; prev = Pointer{Leaf{T, L}}(nothing), next = Pointer{Leaf{T, L}}(nothing)) where {T, L} =
    Leaf(zero(MVector{L, T}), falses(L), prev, next)

childtype(x::Type{<: Leaf}) = nothing
childtype(x::Leaf) = nothing

@inline function Base.getindex(x::Leaf, i::Int)
    @boundscheck checkmask(x, i)
    @inbounds x.data[i]
end

@inline function Base.setindex!(x::Leaf, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        x.data[i] = v
        x.mask[i] = true
    end
    x
end

@inline function Base.setindex!(x::Leaf, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.mask[i] = false
    x
end

cleanup!(x::Leaf) = x
