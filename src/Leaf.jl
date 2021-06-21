struct Leaf{T, N, pow} <: AbstractNode{T, N, pow}
    data::Array{T, N}
    mask::BitArray{N}
end

function Leaf{T, N, pow}() where {T, N, pow}
    @assert isbitstype(T)
    dims = size(Leaf{T, N, pow})
    Leaf{T, N, pow}(Array{T}(undef, dims), falses(dims))
end

@pure childtype(::Type{<: Leaf}) = nothing
@pure leafeltype(::Type{<: Leaf{T}}) where {T} = T

Base.IndexStyle(::Type{<: Leaf}) = IndexLinear()

@inline function Base.getindex(x::Leaf, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        checkmask(x, i)
        x.data[i]
    end
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

allocate!(x::Leaf, i...) = x

cleanup!(x::Leaf) = x
