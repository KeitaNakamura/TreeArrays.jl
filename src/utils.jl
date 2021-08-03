@inline nfill(v, n::Val) = ntuple(i -> v, n)

# cartesian
@inline block_index(child_dims::NTuple{N, Integer}, I::Vararg{Int, N}) where {N} = @. div(I-1, child_dims) + 1
@inline function block_local_index(child_dims::NTuple{N, Integer}, I::Vararg{Int, N}) where {N}
    blockindex = block_index(child_dims, I...)
    localindex = @. I - (blockindex-1) * child_dims
    blockindex, localindex
end


struct Power2 <: Integer
    n::Int
end

function print_superscript(io::IO, i::Int)
    i == 0 && return print(io, Char(0x02070))
    i == 1 && return print(io, Char(0x000B9))
    i == 2 && return print(io, Char(0x000B2))
    i == 3 && return print(io, Char(0x000B3))
    i == 4 && return print(io, Char(0x02074))
    i == 5 && return print(io, Char(0x02075))
    i == 6 && return print(io, Char(0x02076))
    i == 7 && return print(io, Char(0x02077))
    i == 8 && return print(io, Char(0x02078))
    i == 9 && return print(io, Char(0x02079))
    error()
end
function Base.show(io::IO, p::Power2)
    print(io, "2")
    for char in string(p.n)
        print_superscript(io, parse(Int, char))
    end
end

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
