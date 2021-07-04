abstract type AbstractHashNode{T, N, p} <: AbstractNode{T, N, p} end

Base.IndexStyle(::Type{<: AbstractHashNode}) = IndexLinear()

@inline function Base.getindex(x::AbstractHashNode, i::Int)
    @boundscheck checkbounds(x, i)
    isnull(x) && return null(childtype(x))
    # data can haskey even if the mask is false
    # so trying to return stored data
    # in this case, need to handle stored data very carefully because
    # we can change its data unexpectedly even if the mask is false
    get(x.data, i, null(childtype(x)))
end

@inline function Base.setindex!(x::AbstractHashNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    isnull(v) && throw(ArgumentError("trying to set null node, call `delete!(node, i)` instead"))
    @inbounds x.data[i] = v
    x
end

@inline function Base.setindex!(x::AbstractHashNode, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        if isactive(x, i)
            x.data[i] = nothing # make `mask` `false` at `i`
            deactivate!(unsafe_getindex(x, i))
        end
    end
    x
end

@inline function deactivate!(x::AbstractHashNode)
    isnull(x) && return x
    fill!(getmask(x), false)
    foreach(deactivate!, values(x.data))
    x
end

function Base.delete!(x::AbstractHashNode, i)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        # only this case allows to set null node in `x`
        x.data[i] = nothing # make mask false
        delete!(x.data, i) # not set null, just delete it
    end
    x
end

function allocate!(x::AbstractHashNode{T}, i) where {T}
    @boundscheck checkbounds(x, i)
    @inbounds begin
        if haskey(x.data, i)
            childnode = unsafe_getindex(x, i)
        else
            childnode = T()
        end
        x[i] = childnode # activated in setindex!
    end
    childnode
end

isallocated(x::AbstractHashNode, i::Int) = haskey(x.data, i)

struct HashNode{T <: AbstractNode, N, p} <: AbstractHashNode{T, N, p}
    data::HashMaskedArray{T, N}
    HashNode{T, N, p}(data) where {T, N, p} = new(data)
    HashNode{T, N, p}(::UndefInitializer) where {T, N, p} = new()
end

function HashNode{T, N, p}() where {T, N, p}
    dims = size(HashNode{T, N, p})
    data = HashMaskedArray{T}(undef, dims)
    HashNode{T, N, p}(data)
end

Base.size(x::HashNode) = size(typeof(x))


struct DynamicHashNode{T <: AbstractNode, N} <: AbstractHashNode{T, N, Dynamic()}
    data::HashMaskedArray{T, N}
    dims::NTuple{N, Int}
    DynamicHashNode{T, N}(data, dims) where {T, N} = new(data, dims)
    DynamicHashNode{T, N}(::UndefInitializer) where {T, N} = new()
end

function DynamicHashNode{T, N}(dims::Int...) where {T, N}
    data = HashMaskedArray{T}(undef, dims)
    DynamicHashNode{T, N}(data, dims)
end

Base.size(x::DynamicHashNode) = x.dims
