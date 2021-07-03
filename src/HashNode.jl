struct HashNode{T <: AbstractNode, N, p} <: AbstractNode{T, N, p}
    data::HashMaskedArray{T, N}
    HashNode{T, N, p}(data) where {T, N, p} = new(data)
    HashNode{T, N, p}(::Nothing) where {T, N, p} = new()
end

function HashNode{T, N, p}() where {T, N, p}
    dims = size(HashNode{T, N, p})
    data = HashMaskedArray{T}(undef, dims)
    HashNode{T, N, p}(data)
end

@pure childtype(::Type{<: HashNode{T}}) where {T} = T
@pure leaftype(::Type{<: HashNode{T}}) where {T} = leaftype(T)
@pure leafeltype(::Type{<: HashNode{T}}) where {T} = leafeltype(T)

Base.size(x::HashNode) = size(typeof(x))
Base.IndexStyle(::Type{<: HashNode}) = IndexLinear()

@inline function Base.getindex(x::HashNode, i::Int)
    @boundscheck checkbounds(x, i)
    isnull(x) && return null(childtype(x))
    # data can haskey even if the mask is false
    # so trying to return stored data
    # in this case, need to handle stored data very carefully because
    # we can change its data unexpectedly even if the mask is false
    get(x.data, i, null(childtype(x)))
end

@inline function Base.setindex!(x::HashNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    isnull(v) && throw(ArgumentError("trying to set null node, call `delete!(node, i)` instead"))
    @inbounds x.data[i] = v
    x
end

@inline function Base.setindex!(x::HashNode, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        if isactive(x, i)
            x.data[i] = nothing # make `mask` `false` at `i`
            deactivate!(unsafe_getindex(x, i))
        end
    end
    x
end

@inline function deactivate!(x::HashNode)
    isnull(x) && return x
    fillmask!(x, false)
    foreach(deactivate!, values(x.data))
    x
end

function Base.delete!(x::HashNode, i)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        # only this case allows to set null node in `x`
        x.data[i] = nothing # make mask false
        delete!(x.data, i) # not set null, just delete it
    end
    x
end

function allocate!(x::HashNode{T}, i) where {T}
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

isallocated(x::HashNode, i::Int) = haskey(x.data, i)
