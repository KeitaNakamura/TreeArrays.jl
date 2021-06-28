struct MaskedArray{T, N} <: AbstractArray{T, N}
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

@inline Base.isassigned(x::MaskedArray, i::Int...) = (@_propagate_inbounds_meta; isactive(x, i...))
@inline isactive(x::MaskedArray, i...) = (@_propagate_inbounds_meta; x.mask[i...])
allactive(x::MaskedArray) = all(x.mask)
anyactive(x::MaskedArray) = any(x.mask)

@inline checkmask(::Type{Bool}, x::MaskedArray, i...) = (@_propagate_inbounds_meta; isactive(x, i...)) # checkbounds as well
@inline checkmask(x::MaskedArray, i...) = (@_propagate_inbounds_meta; checkmask(Bool, x, i...) ? nothing : throw(UndefRefError()))

@inline function Base.getindex(x::MaskedArray, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        checkmask(x, i)
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

fillmask!(x::MaskedArray, v) = fill!(x.mask, convert(Bool, v))
countmask(x::MaskedArray) = count(x.mask)

# `f` should be `f(mask)`
function findentry(f, x::MaskedArray)
    i = f(vec(x.mask)) # `vec` is not needed for BitArray
    i === nothing ? nothing : @inbounds x[i]
end
