@inline nfill(v, n::Val) = ntuple(i -> v, n)

# cartesian
@inline block_index(child_dims::Tuple, I::Integer...) = @. div(I-1, child_dims) + 1
@inline function block_local_index(child_dims::Tuple, I::Integer...)
    blockindex = block_index(child_dims, I...)
    localindex = @. I - (blockindex-1) * child_dims
    blockindex, localindex
end


struct Power2 <: Integer
    n::Int
end

Base.show(io::IO, p::Power2) = print(io, "2^", p.n)

@inline Base.convert(::Type{T}, p::Power2) where {T <: Integer} = one(T) << unsigned(p.n)

Base.promote_type(::Type{Power2}, ::Type{T}) where {T} = T
Base.promote_type(::Type{T}, ::Type{Power2}) where {T} = T

@inline Base.:*(a::Integer, p::Power2) = a << unsigned(p.n)
@inline Base.:*(p::Power2, a::Integer) = a << unsigned(p.n)

@inline Base.:*(p::Power2, q::Power2) = Power2(p.n + q.n)

@inline Base.div(a::Integer, p::Power2) = a >> unsigned(p.n)
@inline Base.rem(a::Integer, p::Power2) = a & (one(a) << unsigned(p.n) - 1)
@inline Base.divrem(a::Integer, p::Power2) = (div(a, p), rem(a, p))

@inline Base.zero(::Power2) = Power2(0)
