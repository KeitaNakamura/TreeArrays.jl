findfirst_leafnode(node::LeafNode) = findfirst_node(node)
function findfirst_leafnode(node::AbstractNode)
    @inbounds for i in eachindex(node)
        isactive(node, i) && return findfirst_leafnode(node[i])
    end
    nothing
end

findfirst_node_above_leafnode(node::AbstractNode{<: LeafNode}) = findfirst_node(node)
function findfirst_node_above_leafnode(node::AbstractNode)
    @inbounds for i in eachindex(node)
        isactive(node, i) && return findfirst_node_above_leafnode(node[i])
    end
    nothing
end

function findfirst_node(node::AbstractNode)
    prev = get_prev(node)
    prev === nothing && return node
    findfirst_node(prev)
end


struct WalkNodes{Tnode <: AbstractNode}
    parent::Tnode
end
Base.parent(x::WalkNodes) = x.parent

Base.IteratorSize(::Type{<: WalkNodes}) = Base.SizeUnknown()
Base.eltype(::Type{<: WalkNodes{T}}) where {T} = T

function Base.iterate(x::WalkNodes)
    state = findfirst_node(parent(x))
    (state, state)
end

function Base.iterate(x::WalkNodes, state)
    next = get_next(state)
    next === nothing && return nothing
    (next, next)
end


struct FlatVector{pow, T, V <: AbstractArray{T}} <: AbstractVector{T}
    vals::Vector{V}
end

FlatVector{pow}(vals::Vector{V}) where {pow, T, V <: AbstractArray{T}} = FlatVector{pow, T, V}(vals)

_ndims(x::FlatVector) = ndims(eltype(x.vals))

Base.size(x::FlatVector{pow}) where {pow} = (length(x.vals) * 1 << (pow * _ndims(x)),)
@inline function Base.getindex(x::FlatVector{pow}, i::Int) where {pow}
    @boundscheck checkbounds(x, i)
    d, r = _divrem_pow(i-1, pow * _ndims(x))
    @inbounds x.vals[d+1][r+1]
end
@inline function Base.setindex!(x::FlatVector{pow}, v, i::Int) where {pow}
    @boundscheck checkbounds(x, i)
    d, r = _divrem_pow(i-1, pow * _ndims(x))
    @inbounds x.vals[d+1][r+1] = v
    x
end

function leaves(x::AbstractNode; guess_size = false)
    leafnodes = WalkNodes(findfirst_leafnode(x))

    Tleaf = leaftype(x)
    T = fieldtype(Tleaf, :data)
    vals = T[]
    inds = Int[]

    # compute `length` of `leafnodes`
    if guess_size
        len = 0
        for node in WalkNodes(findfirst_node_above_leafnode(x))
            len += countmask(node.data)
        end
        sizehint!(vals, len)
        sizehint!(inds, len * length(Tleaf))
    end

    index = 1
    for leafnode in leafnodes
        push!(vals, leafnode.data)
        @inbounds for i in eachindex(leafnode)
            isactive(leafnode, i) && push!(inds, index)
            index += 1
        end
    end

    view(FlatVector{getpower(Tleaf)}(vals), inds)
end
leaves(x::TreeView; guess_size = false) = leaves(x.node; guess_size)
leaves(x::FlatView; guess_size = false) = leaves(x.node; guess_size)
