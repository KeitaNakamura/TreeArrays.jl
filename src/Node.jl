struct Node{T <: AbstractNode, N, pow} <: AbstractNode{T, N, pow}
    data::MaskedArray{T, N}
    Node{T, N, pow}(data) where {T, N, pow} = new(data)
    Node{T, N, pow}(::Nothing) where {T, N, pow} = new()
end

function Node{T, N, pow}() where {T, N, pow}
    dims = size(Node{T, N, pow})
    data = MaskedArray([null(T) for I in CartesianIndices(dims)])
    Node{T, N, pow}(data)
end

@pure childtype(::Type{<: Node{T}}) where {T} = T
@pure leaftype(::Type{<: Node{T}}) where {T} = leaftype(T)
@pure leafeltype(::Type{<: Node{T}}) where {T} = leafeltype(T)

Base.IndexStyle(::Type{<: Node}) = IndexLinear()

@inline function Base.getindex(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        (isnull(x) || !isactive(x, i)) && return null(childtype(x))
        unsafe_getindex(x, i)
    end
end

@inline function Base.setindex!(x::Node, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i] = v
    x
end

@inline function Base.setindex!(x::Node, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds isactive(x.data, i) && (x.data[i] = null(childtype(x)))
    x
end

@inline function unsafe_getindex(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_getindex(x.data, i)
end

@inline function unsafe_setindex!(x::Node, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_setindex!(x.data, v, i)
end

function free!(x::Node, i...)
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        if isactive(x, i...)
            x[i...] = nothing
        end
        if !isnull(unsafe_getindex(x.data, i...))
            unsafe_setindex!(x.data, null(childtype(x)), i...)
        end
        x
    end
end

function allocate!(x::Node{T}, i...) where {T}
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        if isactive(x, i...)
            childnode = unsafe_getindex(x, i...) # TODO: check really allocated?, should deactivate all entries?
        else
            if isnull(unsafe_getindex(x, i...))
                childnode = T()
            else
                childnode = unsafe_getindex(x, i...) # set itself
                fillmask!(childnode.data, false)
            end
            x[i...] = childnode
        end
    end
    childnode
end

function cleanup!(x::Node)
    @inbounds for i in eachindex(x)
        if isactive(x, i)
            childnode = unsafe_getindex(x, i)
            cleanup!(childnode)
            !anyactive(childnode) && free!(x, i)
        else
            free!(x, i)
        end
    end
    x
end
