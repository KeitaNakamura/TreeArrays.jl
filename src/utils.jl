@inline nfill(v, n::Val) = ntuple(i -> v, n)

# cartesian
@inline block_index(child_dims::NTuple{N, Integer}, I::Vararg{Int, N}) where {N} = @. div(I-1, child_dims) + 1
@inline function block_local_index(child_dims::NTuple{N, Integer}, I::Vararg{Int, N}) where {N}
    blockindex = block_index(child_dims, I...)
    localindex = @. I - (blockindex-1) * child_dims
    blockindex, localindex
end

# getindex like function
for f in (:unsafe_getindex, :isactive, :allocate!, :isallocated)
    _f = Symbol(:_, f)
    @eval begin
        function $f(A::AbstractArray, I...)
            @_propagate_inbounds_meta
            Base.error_if_canonical_getindex(IndexStyle(A), A, I...)
            $_f(IndexStyle(A), A, to_indices(A, I)...)
        end
        function $_f(::IndexLinear, A::AbstractArray, I::Int...)
            @_inline_meta
            @boundscheck checkbounds(A, I...) # generally _to_linear_index requires bounds checking
            @inbounds $f(A, Base._to_linear_index(A, I...))
        end
        function $_f(::IndexCartesian, A::AbstractArray, I::Int)
            @_inline_meta
            @boundscheck checkbounds(A, I...) # generally _to_subscript_indices requires bounds checking
            @inbounds $f(A, Base._to_subscript_indices(A, I...)...)
        end
        function $_f(::IndexCartesian, A::AbstractArray{T,N}, I::Vararg{Int, N}) where {T,N}
            @_propagate_inbounds_meta
            $f(A, I...)
        end
    end
end

# setindex! like function
for f! in (:unsafe_setindex!,)
    _f! = Symbol(:_, f!)
    @eval begin
        function $f!(x::AbstractArray, v, I...)
            @_propagate_inbounds_meta
            Base.error_if_canonical_setindex(IndexStyle(A), A, I...)
            $_f!(IndexStyle(A), A, v, to_indices(A, I)...)
        end
        function $_f!(::IndexLinear, A::AbstractArray, v, I::Int...)
            @_inline_meta
            @boundscheck checkbounds(A, I...) # generally _to_linear_index requires bounds checking
            @inbounds $f!(A, v, Base._to_linear_index(A, I...))
            A
        end
        function $_f!(::IndexCartesian, A::AbstractArray, v, I::Int)
            @_inline_meta
            @boundscheck checkbounds(A, I...) # generally _to_subscript_indices requires bounds checking
            @inbounds $f!(A, v, Base._to_subscript_indices(A, I...)...)
            A
        end
        function $_f!(::IndexCartesian, A::AbstractArray{T,N}, v, I::Vararg{Int, N}) where {T,N}
            @_propagate_inbounds_meta
            $f!(A, v, I...)
            A
        end
    end
end


struct Power2{n} <: Integer
    function Power2{n}() where {n}
        new{n::UInt}()
    end
end
@pure Power2(n::Int) = (@assert n ≥ 0; Power2{unsigned(n)}())
@pure Power2(n::UInt) = Power2{n}()

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
function Base.show(io::IO, p::Power2{n}) where {n}
    print(io, "2")
    for char in string(n)
        print_superscript(io, parse(Int, char))
    end
end

@inline Base.convert(::Type{T}, p::Power2{n}) where {T <: Integer, n} = one(T) << n
Base.promote_type(::Type{<: Power2}, ::Type{T}) where {T} = T
Base.promote_type(::Type{T}, ::Type{<: Power2}) where {T} = T

@inline Base.:*(a::Integer, p::Power2{n}) where {n} = a << n
@inline Base.:*(p::Power2{n}, a::Integer) where {n} = a << n
@inline Base.:*(p::Power2{m}, q::Power2{n}) where {m, n} = Power2(m + n)

@inline Base.div(a::Integer, p::Power2{n}) where {n} = a >> n
@inline Base.rem(a::Integer, p::Power2{n}) where {n} = a & (one(a) << n - 1)
@inline Base.divrem(a::Integer, p::Power2) = (div(a, p), rem(a, p))

@inline Base.zero(::Power2) = Power2(0)
