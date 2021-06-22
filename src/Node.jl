struct Node{T <: AbstractNode, N, pow} <: AbstractNode{T, N, pow}
    data::Array{Base.RefValue{T}, N}
    mask::BitArray{N}
end

function Node{T, N, pow}() where {T, N, pow}
    dims = size(Node{T, N, pow})
    Node{T, N, pow}([Ref(T()) for I in CartesianIndices(dims)], falses(dims))
end

@pure childtype(::Type{<: Node{T}}) where {T} = T
@pure leaftype(::Type{<: Node{T}}) where {T} = leaftype(T)
@pure leafeltype(::Type{<: Node{T}}) where {T} = leafeltype(T)

Base.IndexStyle(::Type{<: Node}) = IndexLinear()

@inline function Base.getindex(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        checkmask(x, i)
        ref = x.data[i]
        ref[]
    end
end

@inline function Base.setindex!(x::Node, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        x.data[i] = Ref(v)
        x.mask[i] = true
    end
    x
end

@inline function Base.setindex!(x::Node, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.mask[i] = false
    x
end

function free!(x::Node, i...)
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        if isactive(x, i...)
            x[i...] = nothing
        end
        if isassigned(x.data[i...])
            x.data[i...] = Ref{eltype(x)}()
        end
        x
    end
end

function allocate!(x::Node{T}, i...) where {T}
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        isactive(x, i...) && return x # TODO: check really allocated?
        if !isassigned(x.data[i...])
            child = T()
        else
            child = x.data[i...][] # set itself
            fill!(child.mask, false)
        end
        x[i...] = child
    end
    x
end

function cleanup!(x::Node)
    @inbounds for i in eachindex(x)
        if isactive(x, i)
            child = x[i]
            cleanup!(child)
            !anyactive(child) && free!(x, i)
        else
            free!(x, i)
        end
    end
    x
end
