struct Node{T <: AbstractNode, L} <: AbstractNode{T, L}
    data::SizedVector{L, Base.RefValue{T}}
    mask::BitVector
    prev::Base.RefValue{Node{T, L}}
    next::Base.RefValue{Node{T, L}}
end

Node{T, L}(; prev = Ref{Node{T, L}}(), next = Ref{Node{T, L}}()) where {T, L} =
    Node(SizedVector{L}([Ref(T()) for i in 1:L]), falses(L), prev, next)

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
        x.mask[i] = true # make it active
        isassigned(x.data[i]) && return x
        x.data[i] = Ref(T())
    end
    x
end

function find_last_activechild(x::Node)
    i = findlast(==(true), x.mask)
    i === nothing && return find_last_activechild(get_prev(x))
    @inbounds x[i]
end
find_last_activechild(::Nothing) = nothing

function find_first_activechild(x::Node)
    i = findfirst(==(true), x.mask)
    i === nothing && return find_first_activechild(get_next(x))
    @inbounds x[i]
end
find_first_activechild(::Nothing) = nothing

function link_child_prev!(x::Node, i::Int)
    @boundscheck checkmask(x, i)

    p = findprev(x.mask, i-1)
    if p !== nothing
        prev = @inbounds x[p]
    else
        prev = find_last_activechild(get_prev(x))
    end

    child = @inbounds x[i]
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

    n = findnext(x.mask, i+1)
    if n !== nothing
        next = @inbounds x[n]
    else
        next = find_first_activechild(get_next(x))
    end

    child = @inbounds x[i]
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

function add_child!(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    allocate!(x, i)
    link_child!(x, i)
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
