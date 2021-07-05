struct TreeArray{T, N, Tnode} <: AbstractArray{T, N}
    tree::TreeView{T, N, Tnode}
    dims::NTuple{N, Int}
    function TreeArray{T, N, Tnode}(tree::TreeView, dims::Tuple) where {T, N, Tnode}
        @assert (CartesianIndices(tree) ∩ CartesianIndices(dims)) == CartesianIndices(dims)
        new(tree, dims)
    end
end

function TreeArray(tree::TreeView{T, N, Tnode}, dims::Tuple) where {T, N, Tnode}
    TreeArray{T, N, Tnode}(tree, dims)
end

function TreeArray(::Type{Tnode}, dims::Int...) where {Tnode <: Union{Node, HashNode}}
    TreeArray(TreeView(Tnode()), dims)
end

function TreeArray(::Type{Tnode}, dims::Int...) where {Tnode <: Union{DynamicNode, DynamicHashNode}}
    t_child = childtype(Tnode)
    blockdims = block_index(dims, totalsize(t_child)...) .+ 1
    tree = TreeView(Tnode(blockdims...))
    TreeArray(tree, dims)
end

Base.size(x::TreeArray) = x.dims

@inline function Base.getindex(x::TreeArray{<: Any, N}, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds x.tree[i...]
end

@inline function Base.setindex!(x::TreeArray{<: Any, N}, v, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds x.tree[i...] = v
    x
end

@inline function isactive(x::TreeArray, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds isactive(x.tree, i...)
end
