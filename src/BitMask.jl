mutable struct BitMask{T <: Unsigned}
    bit::T
end

BitMask{T}() where {T} = BitMask(T(0))

Base.length(x::BitMask) = 8 * sizeof(x.bit)
Base.size(x::BitMask) = (length(x),)

@inline function Base.getindex(mask::BitMask{T}, i::Int) where {T}
    @boundscheck @assert 0 < i < length(mask)+1
    u = T(1) << (i-1)
    (mask.bit & u) != 0
end

@inline function Base.setindex!(mask::BitMask, x, i::Int) where {T}
    @boundscheck @assert 0 < i < length(mask)+1
    u = T(1) << (i-1)
    mask.bit = ifelse(convert(Bool, x), cmask.bit | u, cmask.bit & ~u)
    mask
end

function Base.fill!(mask::BitMask{T}, x) where {T}
    mask.bit = ifelse(convert(Bool, x), ~T(0), T(0))
    mask
end

function Base.show(io::IO, x::BitMask)
    io = IOContext(io, :typeinfo => eltype(x))
    print(io, "<$(length(x)) x Bool>[")
    join(io, [sprint(show, ifelse(x[i], 1, 0); context=io) for i in 1:length(x)], ", ")
    print(io, "]")
end
