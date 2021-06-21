struct Node{T <: AbstractNode, L} <: AbstractNode{T, L}
    data::Vector{Base.RefValue{T}}
    mask::BitVector
    prev::Pointer{Node{T, L}}
    next::Pointer{Node{T, L}}
end

Node{T, L}(; prev = Pointer{Node{T, L}}(nothing), next = Pointer{Node{T, L}}(nothing)) where {T, L} =
    Node([Ref(T()) for i in 1:L], falses(L), prev, next)

childtype(::Type{<: Node{T}}) where {T} = T
childtype(x::Node) = childtype(typeof(x))

@inline function Base.getindex(x::Node, i::Int)
    @boundscheck checkmask(x, i)
    @inbounds ref = x.data[i]
    ref[]
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

@inline function Base.setindex!(x::Node, ::UndefInitializer, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        # x.data[i] = Ref{eltype(x)}()
        x.mask[i] = false
    end
    x
end

function allocate!(x::Node{T}, i::Int) where {T}
    @boundscheck checkbounds(x, i)
    @inbounds begin
        isactive(x, i) && return x # TODO: check really allocated?
        if !isassigned(x.data[i])
            x.data[i] = Ref(T())
        end
        x.mask[i] = true # make it active
        link_child!(x, i)
    end
    x
end

find_last_activechild(::Nothing) = nothing
function find_last_activechild(x::Node)
    i = findlast(==(true), x.mask)
    i === nothing && return find_last_activechild(get_prev(x))
    @inbounds x[i]
end
function find_last_activechild(x::Node, i::Int)
    p = findprev(x.mask, i-1)
    if p !== nothing
        @inbounds x[p]
    else
        find_last_activechild(get_prev(x))
    end
end

find_first_activechild(::Nothing) = nothing
function find_first_activechild(x::Node)
    i = findfirst(==(true), x.mask)
    i === nothing && return find_first_activechild(get_next(x))
    @inbounds x[i]
end
function find_first_activechild(x::Node, i::Int)
    n = findnext(x.mask, i+1)
    if n !== nothing
        @inbounds x[n]
    else
        find_first_activechild(get_next(x))
    end
end

function link_child_prev!(x::Node, i::Int)
    @boundscheck checkmask(x, i)
    child = @inbounds x[i]
    prev = find_last_activechild(x, i)
    if prev !== nothing
        set_prev!(child, prev)
        set_next!(prev, child)
        true
    else
        false
    end
end

function link_child_next!(x::Node, i::Int)
    @boundscheck checkmask(x, i)
    child = @inbounds x[i]
    next = find_first_activechild(x, i)
    if next !== nothing
        set_next!(child, next)
        set_prev!(next, child)
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

function cleanup!(x::Node)
    @inbounds for i in eachindex(x)
        if isactive(x, i)
            child = x[i]
            cleanup!(child)
            if !anyactive(child)
                x.data[i] = Ref{eltype(x)}()
                x.mask[i] = false
            end
        else
            if isassigned(x.data[i])
                x.data[i] = Ref{eltype(x)}()
            end
        end
    end
    x
end
