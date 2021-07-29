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

function TreeArray(::Type{Tnode}, dims::Tuple) where {Tnode <: Union{Node, HashNode}}
    TreeArray(TreeView(Tnode()), dims)
end

function TreeArray(::Type{Tnode}, dims::Tuple) where {Tnode <: Union{DynamicNode, DynamicHashNode}}
    t_child = childtype(Tnode)
    blockdims = block_index(totalsize(t_child), dims...)
    tree = TreeView(Tnode(blockdims...))
    TreeArray(tree, dims)
end
TreeArray(::Type{Tnode}, dims::Int...) where {Tnode} = TreeArray(Tnode, dims)

function TreeArray{T}(dims::NTuple{N, Int}) where {T, N}
    TreeArray(DynamicHashNode{Node{LeafNode{T, N, 3}, N, 4}, N}, dims)
end
TreeArray{T}(dims::Int...) where {T} = TreeArray{T}(dims)

function StructTreeArray(::Type{T}, dims::NTuple{N, Int}) where {T, N}
    TreeArray(DynamicHashNode{Node{@StructLeafNode{T, N, 3}, N, 4}, N}, dims)
end
StructTreeArray(::Type{T}, dims::Int...) where {T} = StructTreeArray(T, dims)
macro StructTreeArray(ex)
    @assert Meta.isexpr(ex, :braces)
    @assert length(ex.args) == 1
    esc(:((dims...) -> $StructTreeArray($(ex.args[1]), dims...)))
end

Base.size(x::TreeArray) = x.dims
leaftype(x::TreeArray) = leaftype(x.tree)
leafeltype(x::TreeArray) = leafeltype(x.tree)

Base.propertynames(x::TreeArray{T}) where {T} = (:tree, :dims, fieldnames(T)...)
function Base.getproperty(x::TreeArray{<: Any, N}, name::Symbol) where {N}
    name == :tree && return getfield(x, :tree)
    name == :dims && return getfield(x, :dims)
    T = fieldtype(leafeltype(x), name)
    PropertyArray{T, N}(x, name)
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
