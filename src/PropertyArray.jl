struct PropertyArray{T, N, name, A <: AbstractArray{<: Any, N}} <: AbstractArray{T, N}
    parent::A
end

PropertyArray{T, N, name}(parent::A) where {T, N, name, A} = PropertyArray{T, N, name, A}(parent)

Base.size(x::PropertyArray) = size(x.parent)
Base.axes(x::PropertyArray) = axes(x.parent)
Base.parent(x::PropertyArray) = x.parent
rootnode(x::PropertyArray) = rootnode(parent(x))
Base.IndexStyle(::Type{<: PropertyArray{<: Any, <: Any, <: Any, A}}) where {A} = IndexStyle(A)

@inline function Base.getindex(x::PropertyArray{<: Any, <: Any, name}, i::Int...) where {name}
    @boundscheck checkbounds(x, i...)
    @inbounds getproperty(x.parent[i...], name)
end

@inline function Base.setindex!(x::PropertyArray{<: Any, <: Any, name}, v, i::Int...) where {name}
    @boundscheck checkbounds(x, i...)
    @inbounds allocated = allocate!(x.parent, i...)
    @inbounds set!(allocated, name, v)
    x
end

@inline function isactive(x::PropertyArray, i...)
    @boundscheck checkbounds(x, i...)
    @inbounds isactive(x.parent, i...)
end
