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
    blockdims = block_index(totalsize(t_child), dims...)
    tree = TreeView(Tnode(blockdims...))
    TreeArray(tree, dims)
end

function TreeArray{T}(dims::Vararg{Int, N}) where {T, N}
    TreeArray(DynamicNode{Node{LeafNode{T, N, 3}, N, 4}, N}, dims...)
end

Base.size(x::TreeArray) = x.dims
leaftype(x::TreeArray) = leaftype(x.tree)
leafeltype(x::TreeArray) = leafeltype(x.tree)

Base.propertynames(x::TreeArray{T}) where {T} = (:tree, :dims, fieldnames(T)...)
function Base.getproperty(x::TreeArray{<: Any, N}, name::Symbol) where {N}
    name == :tree && return getfield(x, :tree)
    name == :dims && return getfield(x, :dims)
    T = fieldtype(leafeltype(x), name)
    TreeArrayProperty{T, N, typeof(x)}(x, name)
end

@inline function Base.getindex(x::TreeArray, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds x.tree[i...]
end

@inline function Base.setindex!(x::TreeArray, v, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds x.tree[i...] = v
    x
end

for f in (:isactive, :allocate!, :isallocated)
    @eval begin
        @inline function $f(x::TreeArray, i...)
            @boundscheck checkbounds(x, i...)
            @inbounds $f(x.tree, i...)
        end
    end
end

function allocate!(x::TreeArray, mask::AbstractArray{Bool})
    promote_shape(x, mask)
    allocate!(x.tree.rootnode, mask)
end

cleanup!(x::TreeArray) = (cleanup!(x.tree); x)

Base.fill!(x::TreeArray, ::Nothing) = (fill!(x.tree, nothing); x)


struct TreeArrayProperty{T, N, A <: TreeArray{<: Any, N}} <: AbstractArray{T, N}
    parent::A
    name::Symbol
end

Base.size(x::TreeArrayProperty) = size(x.parent)
leaftype(x::TreeArrayProperty) = leaftype(x.parent)
leafeltype(x::TreeArrayProperty) = leafeltype(x.parent)

@inline function Base.getindex(x::TreeArrayProperty{<: Any, N}, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds getproperty(x.parent[i...], x.name)
end

@inline function Base.setindex!(x::TreeArrayProperty{<: Any, N}, v, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds leaf = allocate!(x.parent, i...)
    @inbounds setproperty!(leaf, x.name, v)
    x
end

@inline function isactive(x::TreeArrayProperty, i...)
    @boundscheck checkbounds(x, i...)
    @inbounds isactive(x.parent, i...)
end
