abstract type MaskedArray{T, N} <: AbstractArray{T, N} end

@inline isactive(x::MaskedArray, i::Int) = (@_propagate_inbounds_meta; getmask(x)[i])
@inline checkactive(::Type{Bool}, x::MaskedArray, i::Int) = (@_propagate_inbounds_meta; isactive(x, i)) # checkbounds as well
@inline checkactive(x::MaskedArray, i::Int) = (@_propagate_inbounds_meta; checkactive(Bool, x, i) || throw(UndefRefError()))

@inline function Base.getindex(x::MaskedArray, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        checkactive(x, i)
        x.data[i]
    end
end

@inline function Base.setindex!(x::MaskedArray, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        x.data[i] = v
        x.mask[i] = true
    end
    x
end

@inline function Base.setindex!(x::MaskedArray, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.mask[i] = false
    x
end

@inline function unsafe_getindex(x::MaskedArray, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i]
end

@inline function unsafe_setindex!(x::MaskedArray, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i] = v
    v
end

getmask(x::MaskedArray) = x.mask

# `f` should be `f(mask)`
function findentry(f, x::MaskedArray)
    i = f(vec(x.mask)) # `vec` is not needed for BitArray
    i === nothing ? nothing : @inbounds x[i]
end


struct MaskedDenseArray{T, N} <: MaskedArray{T, N}
    data::Array{T, N}
    mask::Array{Bool, N} # faster than BitArray?
end

@inline function MaskedDenseArray{T}(::UndefInitializer, dims::NTuple{N, Int}) where {T, N}
    data = Array{T}(undef, dims)
    mask = fill!(similar(data, Bool), false)
    MaskedDenseArray(data, mask)
end
@inline MaskedDenseArray{T}(u::UndefInitializer, dims::Vararg{Int, N}) where {T, N} =
    MaskedDenseArray{T}(u, dims)
@inline function MaskedDenseArray(data::Array)
    mask = fill!(similar(data, Bool), false)
    MaskedDenseArray(data, mask)
end

Base.IndexStyle(::Type{<: MaskedDenseArray}) = IndexLinear()
Base.size(x::MaskedDenseArray) = size(x.data)

@inline Base.isassigned(x::MaskedDenseArray, i::Int) = isassigned(x.data, i)


struct MaskedStructArray{T, N, Ttuple} <: MaskedArray{T, N}
    data::StructArray{T, N, Ttuple, Int}
    mask::Array{Bool, N} # faster than BitArray?
end

@inline function MaskedStructArray{T}(::UndefInitializer, dims::NTuple{N, Int}) where {T, N}
    data = StructArray{T}(undef, dims)
    mask = fill!(similar(data, Bool), false)
    MaskedStructArray(data, mask)
end
@inline MaskedStructArray{T}(u::UndefInitializer, dims::Vararg{Int, N}) where {T, N} =
    MaskedStructArray{T}(u, dims)
@inline function MaskedStructArray(data::StructArray)
    mask = fill!(similar(data, Bool), false)
    MaskedStructArray(data, mask)
end

Base.propertynames(x::MaskedStructArray) = (:data, :mask, propertynames(x.data)...)
@inline function Base.getproperty(x::MaskedStructArray, name::Symbol)
    name == :data && return getfield(x, :data)
    name == :mask && return getfield(x, :mask)
    MaskedDenseArray(getproperty(getfield(x, :data), name), getfield(x, :mask))
end

Base.IndexStyle(::Type{<: MaskedStructArray}) = IndexLinear()
Base.size(x::MaskedStructArray) = size(x.data)

@inline Base.isassigned(x::MaskedStructArray, i::Int) = isassigned(x.data, i)


# https://discourse.julialang.org/t/poor-time-performance-on-dict/9656/14
struct FastHashInt; i::Int; end
Base.:(==)(x::FastHashInt, y::FastHashInt) = x.i == y.i
Base.hash(x::FastHashInt, h::UInt) = xor(UInt(x.i), h)

struct MaskedHashArray{T, N} <: MaskedArray{T, N}
    data::Dict{FastHashInt, T}
    mask::Array{Bool, N}
    dims::NTuple{N, Int}
end

@inline function MaskedHashArray{T}(::UndefInitializer, dims::NTuple{N, Int}) where {T, N}
    data = Dict{FastHashInt, T}()
    mask = fill!(Array{Bool}(undef, dims), false)
    MaskedHashArray(data, mask, dims)
end
@inline MaskedHashArray{T}(u::UndefInitializer, dims::Vararg{Int, N}) where {T, N} =
    MaskedHashArray{T}(u, dims)

Base.IndexStyle(::Type{<: MaskedHashArray}) = IndexLinear()
Base.size(x::MaskedHashArray) = x.dims

# Base.keys(x::MaskedHashArray) = keys(x.data) # disable because of using FastHashInt
Base.values(x::MaskedHashArray) = values(x.data)
Base.haskey(x::MaskedHashArray, i) = haskey(x.data, FastHashInt(i))
Base.delete!(x::MaskedHashArray, i) = delete!(x.data, FastHashInt(i))

@inline function Base.get(x::MaskedHashArray, i::Int, default)
    get(x.data, FastHashInt(i), default)
end

@inline function Base.getindex(x::MaskedHashArray, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        checkactive(x, i)
        x.data[FastHashInt(i)]
    end
end

@inline function Base.setindex!(x::MaskedHashArray, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        x.data[FastHashInt(i)] = v
        x.mask[i] = true
    end
    x
end
@inline function Base.setindex!(x::MaskedHashArray, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.mask[i] = false
    x
end

@inline function unsafe_getindex(x::MaskedHashArray, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[FastHashInt(i)]
end

@inline function unsafe_setindex!(x::MaskedHashArray, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[FastHashInt(i)] = v
    v
end
