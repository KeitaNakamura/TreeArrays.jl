struct Node{T <: AbstractNode, N, pow} <: AbstractNode{T, N, pow}
    data::MaskedArray{Base.RefValue{T}, N}
    prev::Pointer{Node{T, N, pow}}
    next::Pointer{Node{T, N, pow}}
end

function Node{T, N, pow}() where {T, N, pow}
    dims = size(Node{T, N, pow})
    data = MaskedArray([Ref{T}() for I in CartesianIndices(dims)])
    prev = Pointer{Node{T, N, pow}}(nothing)
    next = Pointer{Node{T, N, pow}}(nothing)
    Node{T, N, pow}(data, prev, next)
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
    @inbounds begin
        x.data[i] = Ref(v)
        link_child!(x, i)
    end
    x
end

@inline function Base.setindex!(x::Node, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        if isactive(x.data, i)
            x.data[i] = nothing
            link!(findlast_activechild(x, i), findfirst_activechild(x, i))
        end
    end
    x
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
            childnode = x[i...] # TODO: check really allocated?, should deactivate all entries?
        else
            if !isassigned(unsafe_getindex(x.data, i...))
                childnode = T()
            else
                childnode = unsafe_getindex(x.data, i...)[] # set itself
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
            childnode = x[i]
            cleanup!(childnode)
            !anyactive(childnode) && free!(x, i)
        else
            free!(x, i)
        end
    end
    x
end

findlast_activechild(::Nothing) = nothing
function findlast_activechild(x::Node)
    child = findentry(findlast, x.data)
    child === nothing ? findlast_activechild(get_prev(x)) : child[]
end
function findlast_activechild(x::Node, i::Int)
    child = findentry(x -> findprev(x, i-1), x.data)
    child === nothing ? findlast_activechild(get_prev(x)) : child[]
end

findfirst_activechild(::Nothing) = nothing
function findfirst_activechild(x::Node)
    child = findentry(findfirst, x.data)
    child === nothing ? findfirst_activechild(get_next(x)) : child[]
end
function findfirst_activechild(x::Node, i::Int)
    child = findentry(x -> findnext(x, i+1), x.data)
    child === nothing ? findfirst_activechild(get_next(x)) : child[]
end

link!(x::T, y::T) where {T <: AbstractNode} = (set_next!(x, y); set_prev!(y, x); nothing)
link!(x::AbstractNode, y::Nothing) = (set_next!(x, y); nothing)
link!(x::Nothing, y::AbstractNode) = (set_prev!(y, x); nothing)
link!(x::Nothing, y::Nothing) = nothing

function link_child_prev!(x::Node, i::Int)
    checkmask(x.data, i)
    prev = findlast_activechild(x, i)
    link!(prev, x[i])
end

function link_child_next!(x::Node, i::Int)
    checkmask(x.data, i)
    next = findfirst_activechild(x, i)
    link!(x[i], next)
end

function link_child!(x::Node, i::Int)
    link_child_prev!(x, i)
    link_child_next!(x, i)
    x
end
