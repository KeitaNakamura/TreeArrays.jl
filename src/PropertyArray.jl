struct PropertyArray{T, N, A <: AbstractArray{<: Any, N}} <: AbstractArray{T, N}
    parent::A
    name::Symbol
end

PropertyArray{T, N}(parent::A, name::Symbol) where {T, N, A} = PropertyArray{T, N, A}(parent, name)

Base.size(x::PropertyArray) = size(x.parent)

@inline function Base.getindex(x::PropertyArray{<: Any, N}, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds getproperty(x.parent[i...], x.name)
end

@inline function Base.setindex!(x::PropertyArray{<: Any, N}, v, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds allocated = allocate!(x.parent, i...)
    @inbounds set!(allocated, x.name, v)
    x
end

@inline function isactive(x::PropertyArray, i...)
    @boundscheck checkbounds(x, i...)
    @inbounds isactive(x.parent, i...)
end
