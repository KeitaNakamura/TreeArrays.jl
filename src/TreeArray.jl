abstract type AbstractTreeArray{T, N} <: AbstractArray{T, N} end

Base.size(x::AbstractTreeArray) = x.dims
leaftype(x::AbstractTreeArray) = leaftype(x.tree)
leafeltype(x::AbstractTreeArray) = leafeltype(x.tree)
nleafblocks(x::AbstractTreeArray) = @. ($size(x) - 1) ÷ $leafblockunit(x) + 1
leafblockunit(x::AbstractTreeArray) = leafblockunit(x.tree)
rootnode(x::AbstractTreeArray) = rootnode(x.tree)

@inline function Base.getindex(x::AbstractTreeArray{<: Any, N}, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds x.tree[i...]
end

@inline function Base.setindex!(x::AbstractTreeArray{<: Any, N}, v, i::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, i...)
    @inbounds x.tree[i...] = v
    x
end

for f in (:isactive, :allocate!, :isallocated)
    @eval @inline function $f(x::AbstractTreeArray{<: Any, N}, I::Vararg{Int, N}) where {N}
        @boundscheck checkbounds(x, I...)
        @inbounds $f(x.tree, I...)
    end
end

function allocate!(x::AbstractTreeArray, mask::AbstractArray{Bool})
    promote_shape(x, mask)
    allocate!(rootnode(x.tree), mask)
end

cleanup!(x::AbstractTreeArray) = (cleanup!(x.tree); x)
Base.fill!(x::AbstractTreeArray, ::Nothing) = (fill!(x.tree, nothing); x)


struct TreeArray{T, N, Tnode} <: AbstractTreeArray{T, N}
    tree::TreeView{T, N, Tnode}
    dims::NTuple{N, Int}
    function TreeArray{T, N, Tnode}(tree::TreeView, dims::Tuple) where {T, N, Tnode}
        @assert (CartesianIndices(tree) ∩ CartesianIndices(dims)) == CartesianIndices(dims)
        @assert leaftype(Tnode) <: LeafNode
        new(tree, dims)
    end
end

function TreeArray{T}(dims::NTuple{N, Int}) where {T, N}
    TreeArray(DynamicHashNode{Node{LeafNode{T, N, 3}, N, 4}, N}, dims)
end

struct StructTreeArray{T, N, Tnode} <: AbstractTreeArray{T, N}
    tree::TreeView{T, N, Tnode}
    dims::NTuple{N, Int}
    function StructTreeArray{T, N, Tnode}(tree::TreeView, dims::Tuple) where {T, N, Tnode}
        @assert (CartesianIndices(tree) ∩ CartesianIndices(dims)) == CartesianIndices(dims)
        @assert leaftype(Tnode) <: StructLeafNode
        new(tree, dims)
    end
end

function StructTreeArray{T}(dims::NTuple{N, Int}) where {T, N}
    StructTreeArray(DynamicHashNode{Node{@StructLeafNode{T, N, 3}, N, 4}, N}, dims)
end

Base.propertynames(x::StructTreeArray{T}) where {T} = (:tree, :dims, fieldnames(T)...)
@inline function Base.getproperty(x::StructTreeArray{<: Any, N}, name::Symbol) where {N}
    name == :tree && return getfield(x, :tree)
    name == :dims && return getfield(x, :dims)
    T = fieldtype(leafeltype(x), name)
    PropertyArray{T, N, name}(x)
end


# construtors
for TreeArrayType in (:TreeArray, :StructTreeArray)
    @eval begin
        function $TreeArrayType(tree::TreeView{T, N, Tnode}, dims::Tuple) where {T, N, Tnode}
            $TreeArrayType{T, N, Tnode}(tree, dims)
        end

        function $TreeArrayType(::Type{Tnode}, dims::Tuple) where {Tnode <: Union{Node, HashNode}}
            $TreeArrayType(TreeView(Tnode()), dims)
        end

        function $TreeArrayType(::Type{Tnode}, dims::Tuple) where {Tnode <: Union{DynamicNode, DynamicHashNode}}
            t_child = childtype(Tnode)
            blockdims = block_index(totalsize(t_child), dims...)
            tree = TreeView(Tnode(blockdims...))
            $TreeArrayType(tree, dims)
        end
        $TreeArrayType(::Type{Tnode}, dims::Int...) where {Tnode} = $TreeArrayType(Tnode, dims)

        $TreeArrayType{T}(dims::Int...) where {T} = $TreeArrayType{T}(dims)
    end
end
