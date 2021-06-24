struct Node{T <: AbstractNode, N, pow} <: AbstractNode{T, N, pow}
    data::Array{Base.RefValue{T}, N}
    mask::BitArray{N}
    prev::Pointer{Node{T, N, pow}}
    next::Pointer{Node{T, N, pow}}
end

function Node{T, N, pow}() where {T, N, pow}
    dims = size(Node{T, N, pow})
    data = [Ref{T}() for I in CartesianIndices(dims)]
    prev = Pointer{Node{T, N, pow}}(nothing)
    next = Pointer{Node{T, N, pow}}(nothing)
    Node{T, N, pow}(data, falses(dims), prev, next)
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
        link_child!(x, i)
    end
    x
end

@inline function Base.setindex!(x::Node, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        if x.mask[i]
            x.mask[i] = false
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
        if isassigned(x.data[i...])
            x.data[i...] = Ref{eltype(x)}()
        end
        x
    end
end

function allocate!(x::Node{T}, i...) where {T}
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        isactive(x, i...) && return x[i...] # TODO: check really allocated?
        if !isassigned(x.data[i...])
            child = T()
        else
            child = x.data[i...][] # set itself
            fill!(child.mask, false)
        end
        x[i...] = child
    end
    child
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

findlast_activechild(::Nothing) = nothing
function findlast_activechild(x::Node)
    i = findlast(==(true), x.mask)
    i === nothing && return findlast_activechild(get_prev(x))
    @inbounds x[i]
end
function findlast_activechild(x::Node, i::Int)
    p = findprev(x.mask, i-1)
    if p !== nothing
        @inbounds x[p]
    else
        findlast_activechild(get_prev(x))
    end
end

findfirst_activechild(::Nothing) = nothing
function findfirst_activechild(x::Node)
    i = findfirst(==(true), x.mask)
    i === nothing && return findfirst_activechild(get_next(x))
    @inbounds x[i]
end
function findfirst_activechild(x::Node, i::Int)
    n = findnext(x.mask, i+1)
    if n !== nothing
        @inbounds x[n]
    else
        findfirst_activechild(get_next(x))
    end
end

link!(x::T, y::T) where {T <: AbstractNode} = (set_next!(x, y); set_prev!(y, x); nothing)
link!(x::AbstractNode, y::Nothing) = (set_next!(x, y); nothing)
link!(x::Nothing, y::AbstractNode) = (set_prev!(y, x); nothing)
link!(x::Nothing, y::Nothing) = nothing

function link_child_prev!(x::Node, i::Int)
    @boundscheck checkmask(x, i)
    child = @inbounds x[i]
    prev = findlast_activechild(x, i)
    if prev !== nothing
        link!(prev, child)
        true
    else
        false
    end
end

function link_child_next!(x::Node, i::Int)
    @boundscheck checkmask(x, i)
    child = @inbounds x[i]
    next = findfirst_activechild(x, i)
    if next !== nothing
        link!(child, next)
        true
    else
        false
    end
end

function link_child!(x::Node, i::Int)
    @boundscheck checkmask(x, i)
    @inbounds begin
        link_child_prev!(x, i)
        link_child_next!(x, i)
    end
    x
end
