struct Node{T <: AbstractNode, N, pow} <: AbstractNode{T, N, pow}
    data::MaskedArray{Base.RefValue{T}, N}
end

function Node{T, N, pow}() where {T, N, pow}
    dims = size(Node{T, N, pow})
    data = MaskedArray([Ref{T}() for I in CartesianIndices(dims)])
    Node{T, N, pow}(data)
end

@pure childtype(::Type{<: Node{T}}) where {T} = T
@pure leaftype(::Type{<: Node{T}}) where {T} = leaftype(T)
@pure leafeltype(::Type{<: Node{T}}) where {T} = leafeltype(T)

Base.IndexStyle(::Type{<: Node}) = IndexLinear()

@inline function Base.getindex(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        ref = x.data[i]
        ref[]
    end
end

@inline function Base.setindex!(x::Node, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i] = Ref(v)
    x
end

@inline function Base.setindex!(x::Node, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds isactive(x.data, i) && (x.data[i] = nothing)
    x
end

@inline function unsafe_getindex(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_getindex(x.data, i)[]
end

@inline function unsafe_setindex!(x::Node, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_setindex!(x.data, Ref(v), i)
end

function free!(x::Node, i...)
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        if isactive(x, i...)
            x[i...] = nothing
        end
        if isassigned(unsafe_getindex(x.data, i...))
            unsafe_setindex!(x.data, Ref{eltype(x)}(), i...)
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
            if !isassigned(unsafe_getindex(x.data, i...))
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
