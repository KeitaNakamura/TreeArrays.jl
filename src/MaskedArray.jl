abstract type AbstractMaskedArray{T, N} <: AbstractArray{T, N} end

@inline Base.isassigned(x::AbstractMaskedArray, i::Int...) = (@_propagate_inbounds_meta; isactive(x, i...))
@inline isactive(x::AbstractMaskedArray, i::Int...) = (@_propagate_inbounds_meta; x.mask[i...])
allactive(x::AbstractMaskedArray) = all(x.mask)
anyactive(x::AbstractMaskedArray) = any(x.mask)

@inline checkmask(::Type{Bool}, x::AbstractMaskedArray, i::Int...) = (@_propagate_inbounds_meta; isactive(x, i...)) # checkbounds as well
@inline checkmask(x::AbstractMaskedArray, i::Int...) = (@_propagate_inbounds_meta; checkmask(Bool, x, i...) || throw(UndefRefError()))

@inline function Base.getindex(x::AbstractMaskedArray, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        checkmask(x, i)
        x.data[i]
    end
end

@inline function Base.setindex!(x::AbstractMaskedArray, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        x.data[i] = v
        x.mask[i] = true
    end
    x
end

@inline function Base.setindex!(x::AbstractMaskedArray, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.mask[i] = false
    x
end

@inline function unsafe_getindex(x::AbstractMaskedArray, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i]
end

@inline function unsafe_setindex!(x::AbstractMaskedArray, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i] = v
    v
end

fillmask!(x::AbstractMaskedArray, v) = fill!(x.mask, convert(Bool, v))
countmask(x::AbstractMaskedArray) = count(x.mask)

# `f` should be `f(mask)`
function findentry(f, x::AbstractMaskedArray)
    i = f(vec(x.mask)) # `vec` is not needed for BitArray
    i === nothing ? nothing : @inbounds x[i]
end


struct MaskedArray{T, N} <: AbstractMaskedArray{T, N}
    data::Array{T, N}
    mask::Array{Bool, N} # faster than BitArray?
end

@inline function MaskedArray{T}(::UndefInitializer, dims::NTuple{N, Int}) where {T, N}
    data = Array{T}(undef, dims)
    mask = fill!(similar(data, Bool), false)
    MaskedArray(data, mask)
end
@inline function MaskedArray(data::Array)
    mask = fill!(similar(data, Bool), false)
    MaskedArray(data, mask)
end

Base.IndexStyle(::Type{<: MaskedArray}) = IndexLinear()
Base.size(x::MaskedArray) = size(x.data)


struct HashMaskedArray{T, N} <: AbstractMaskedArray{T, N}
    data::OrderedDict{Int, T}
    mask::Array{Bool, N}
    dims::NTuple{N, Int}
end

@inline function HashMaskedArray{T}(::UndefInitializer, dims::NTuple{N, Int}) where {T, N}
    data = OrderedDict{Int, T}()
    mask = fill!(Array{Bool}(undef, dims), false)
    HashMaskedArray(data, mask, dims)
end

Base.IndexStyle(::Type{<: HashMaskedArray}) = IndexLinear()
Base.size(x::HashMaskedArray) = x.dims

Base.keys(x::HashMaskedArray) = keys(x.data)
Base.values(x::HashMaskedArray) = values(x.data)
Base.haskey(x::HashMaskedArray, i) = haskey(x.data, i)
Base.delete!(x::HashMaskedArray, i) = delete!(x.data, i)
