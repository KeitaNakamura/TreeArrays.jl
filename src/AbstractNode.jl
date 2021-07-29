abstract type AbstractNode{T, N, p} <: AbstractArray{T, N} end

@pure Base.size(::Type{Tnode}) where {Tnode <: AbstractNode} = convert.(Int, TreeSize(Tnode)[1])
@pure totalsize(::Type{Tnode}) where {Tnode <: AbstractNode} = totalsize(TreeSize(Tnode))

# null
@pure null(::Type{Tnode}) where {Tnode <: AbstractNode} = Tnode(undef)
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

getmask(x::AbstractNode) = getmask(x.data)
isactive(x::AbstractNode, i...) = (@_propagate_inbounds_meta; isnull(x) ? false : getmask(x)[i...])

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

@inline function allocate!(x::AbstractNode, i::CartesianIndex)
    @boundscheck checkbounds(x, i)
    @inbounds allocate!(x, Base._sub2ind(size(x), Tuple(i)...))
end

function allocate!(node::AbstractNode, mask::AbstractArray{Bool})
    checkbounds(CartesianIndices(totalsize(node)), CartesianIndices(mask))
    dims = totalsize(Base.tail(TreeSize(node)))
    for I in CartesianIndices(node)
        start = CartesianIndex(@. dims * ($Tuple(I) - 1) + 1)
        stop = min(CartesianIndex(@. $Tuple(start) + dims - 1), last(CartesianIndices(mask)))
        childmask = @view mask[start:stop]
        if any(childmask)
            child = allocate!(node, I)
            allocate!(child, childmask)
        end
    end
end

function cleanup!(x::AbstractNode)
    @inbounds for i in eachindex(x)
        if isactive(x, i)
            # if `i` is active, then child node is always not null
            childnode = unsafe_getindex(x, i)
            cleanup!(childnode)
            !any(getmask(childnode)) && delete!(x, i)
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


struct Dynamic end
struct TreeSize{S}
    function TreeSize{S}() where {S}
        new{S::Tuple{Vararg{Union{Tuple{Vararg{Integer}}, Dynamic}}}}()
    end
end
@pure TreeSize(S::Tuple) = TreeSize{S}()
@pure Base.Tuple(::TreeSize{S}) where {S} = S

@pure nodesize(::Type{<: AbstractNode{<: Any, <: Any, Dynamic()}}) = Dynamic()
@pure nodesize(::Type{<: AbstractNode{<: Any, N, p}}) where {N, p} = nfill(Power2(p), Val(N))
@pure TreeSize(::Nothing) = TreeSize{()}()
@pure TreeSize(::Type{Tnode}) where {Tnode <: AbstractNode} = TreeSize{(nodesize(Tnode), Tuple(TreeSize(childtype(Tnode)))...)}()
@pure TreeSize(x::AbstractNode) = TreeSize(typeof(x))

@pure Base.length(::TreeSize{S}) where {S} = length(S)
@pure Base.getindex(::TreeSize{S}, i::Int) where {S} = S[i]
@pure Base.firstindex(::TreeSize) = 1
@pure Base.lastindex(x::TreeSize) = length(x)
@pure Base.tail(::TreeSize{S}) where {S} = length(S) == 1 ? TreeSize{(map(zero, S[1]),)}() : TreeSize{Base.tail(S)}()
@pure totalsize(::TreeSize{S}) where {S} = broadcast(*, S...)

Base.show(io::IO, ::TreeSize{S}) where {S} = print(io, "TreeSize", S)


struct Allocated{P, I}
    parent::P
    index::I
end
@inline set!(x::Allocated, v) = @inbounds x.parent[x.index] = v
@inline set!(x::Allocated, name::Symbol, v) = @inbounds getproperty(x.parent, name)[x.index] = v
@inline function allocate!(x::Allocated, i...)
    @_propagate_inbounds_meta
    child = @inbounds x.parent[x.index]
    allocate!(child, i...)
end
@inline function Base.setindex!(x::Allocated, v, i...)
    @_propagate_inbounds_meta
    child = @inbounds x.parent[x.index]
    setindex!(child, v, i...)
end
