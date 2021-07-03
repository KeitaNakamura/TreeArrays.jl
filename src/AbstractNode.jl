abstract type AbstractNode{T, N, p} <: AbstractArray{T, N} end

@pure Base.size(::Type{Tnode}) where {Tnode <: AbstractNode} = convert.(Int, TreeSize(Tnode)[1])

# null
@pure null(::Type{Tnode}) where {Tnode <: AbstractNode} = Tnode(nothing)
null(x::AbstractNode) = null(typeof(x))
isnull(x::AbstractNode) = x === null(x)

# childtype
@pure childtype(::Type{<: AbstractNode}) = nothing
@pure childtype(::Type{<: AbstractNode{T}}) where {T <: AbstractNode} = T
childtype(x::AbstractNode) = childtype(typeof(x))

# leaftype
@pure leaftype(T::Type{<: AbstractNode}) = T
@pure leaftype(::Type{<: AbstractNode{T}}) where {T <: AbstractNode} = leaftype(T)
leaftype(x::AbstractNode) = leaftype(typeof(x))

# leafeltype
@pure leafeltype(T::Type{<: AbstractNode}) = eltype(leaftype(T))
leafeltype(x::AbstractNode) = leafeltype(typeof(x))

isactive(x::AbstractNode, i...) = (@_propagate_inbounds_meta; isnull(x) ? false : isactive(x.data, i...))
allactive(x::AbstractNode) = allactive(x.data)
anyactive(x::AbstractNode) = anyactive(x.data)

fillmask!(x::AbstractNode, v) = fillmask!(x.data, v)

@inline function Base.getindex(x::AbstractNode, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds x[Base._sub2ind(size(x), i...)]
end

@inline function Base.setindex!(x::AbstractNode, v, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds x[Base._sub2ind(size(x), i...)] = v
end

@inline function unsafe_getindex(x::AbstractNode, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_getindex(x.data, i)
end

@inline function unsafe_setindex!(x::AbstractNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_setindex!(x.data, v, i)
end

@inline function unsafe_getindex(x::AbstractNode, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds unsafe_getindex(x, Base._sub2ind(size(x), i...))
end

@inline function unsafe_setindex!(x::AbstractNode, v, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds unsafe_setindex!(x, v, Base._sub2ind(size(x), i...))
end

function cleanup!(x::AbstractNode)
    @inbounds for i in eachindex(x)
        if isactive(x, i)
            # if `i` is active, then child node is always not null
            childnode = unsafe_getindex(x, i)
            cleanup!(childnode)
            !anyactive(childnode) && delete!(x, i)
        else
            delete!(x, i)
        end
    end
    x
end

function nleaves(x::AbstractNode)
    isnull(x) && return 0
    count = 0
    @inbounds for i in eachindex(x)
        if isactive(x, i)
            child = unsafe_getindex(x, i)
            count += nleaves(child)
        end
    end
    count
end


struct TreeSize{S}
    function TreeSize{S}() where {S}
        new{S::Tuple{Vararg{Tuple{Vararg{Integer}}}}}()
    end
end
@pure TreeSize(S::Tuple) = TreeSize{S}()
@pure Base.Tuple(::TreeSize{S}) where {S} = S

@pure TreeSize(::Nothing) = TreeSize{()}()
@pure TreeSize(::Type{Tnode}) where {N, p, Tnode <: AbstractNode{<: Any, N, p}} = TreeSize{(nfill(Power2(p), Val(N)), Tuple(TreeSize(childtype(Tnode)))...)}()
@pure TreeSize(x::AbstractNode) = TreeSize(typeof(x))

@pure Base.length(::TreeSize{S}) where {S} = length(S)
@pure Base.getindex(::TreeSize{S}, i::Int) where {S} = S[i]
@pure Base.firstindex(::TreeSize) = 1
@pure Base.lastindex(x::TreeSize) = length(x)
@pure Base.tail(::TreeSize{S}) where {S} = length(S) == 1 ? TreeSize{(map(zero, S[1]),)}() : TreeSize{Base.tail(S)}()
@pure totalsize(::TreeSize{S}) where {S} = broadcast(*, S...)

Base.show(io::IO, ::TreeSize{S}) where {S} = print(io, "TreeSize", S)
