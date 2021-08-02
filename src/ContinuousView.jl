struct ContinuousView{T, N, p, Tnode <: AbstractNode{<: Any, N}, Tblocks <: AbstractArray{<: AbstractLeafNode{T, N, p}, N}, Tindices <: Tuple} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Tblocks
    indices::Tindices
    blockoffset::NTuple{N, Int}
end

struct BlockLocalIndex{N}
    globalindex::NTuple{N, Int}
    blockindex::Int
    localindex::Int
end
@inline function BlockLocalIndex(x::ContinuousView, I::Int...)
    dims = TreeSize(parent(x))[end]
    blockindex, localindex = block_local_index(dims, I...)
    blocklinear = Base._sub2ind(size(x.blocks), (blockindex .- blockoffset(x))...)
    locallinear = Base._sub2ind(dims, localindex...)
    BlockLocalIndex(I, blocklinear, locallinear)
end
BlockLocalIndex(x::ContinuousView, I::CartesianIndex) = BlockLocalIndex(x, Tuple(I)...)

Base.size(x::ContinuousView) = map(length, x.indices)
Base.axes(x::ContinuousView) = Base.IdentityUnitRange.(x.indices)
Base.parent(x::ContinuousView) = x.parent
rootnode(x::ContinuousView) = parent(x)

Base.propertynames(x::ContinuousView{<: Any, <: Any, <: Any, <: Any, <: AbstractArray{<: StructLeafNode}}) = (:parent, :blocks, :indices, fieldnames(eltype(x))...)
@inline function Base.getproperty(x::ContinuousView{<: Any, N, <: Any, <: Any, <: AbstractArray{<: StructLeafNode}}, name::Symbol) where {N}
    name == :parent && return getfield(x, :parent)
    name == :blocks && return getfield(x, :blocks)
    name == :indices && return getfield(x, :indices)
    name == :blockoffset && return getfield(x, :blockoffset)
    T = fieldtype(leafeltype(parent(x)), name)
    PropertyArray{T, N, name}(x)
end

blockoffset(x::ContinuousView) = x.blockoffset

for f in (:(Base.getindex), :isactive, :allocate!)
    @eval @inline function $f(x::ContinuousView, I::BlockLocalIndex)
        @_propagate_inbounds_meta
        @inbounds begin
            block = x.blocks[I.blockindex]
            $f(block, I.localindex)
        end
    end
end

@inline function Base.setindex!(x::ContinuousView, v, I::BlockLocalIndex)
    @_propagate_inbounds_meta
    block = x.blocks[I.blockindex]
    if isnull(block)
        leaf = _setindex!_getleaf(TreeView(parent(x)), v, I.globalindex...)
        x.blocks[I.blockindex] = leaf
    else
        block[I.localindex] = v
    end
    x
end

for f in (:(Base.getindex), :isactive, :allocate!)
    @eval @inline function $f(x::ContinuousView{<: Any, N}, I::Vararg{Int, N}) where {N}
        @boundscheck checkbounds(x, I...)
        @inbounds $f(x, BlockLocalIndex(x, I...))
    end
end

@inline function Base.setindex!(x::ContinuousView{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    @inbounds setindex!(x, v, BlockLocalIndex(x, I...))
end

function _continuousview(parentdims::Tuple, A::TreeView{<: Any, N}, I::Vararg{Union{Int, AbstractUnitRange, Colon}, N}) where {N}
    indices = to_indices(A, I)
    node = rootnode(A)
    dims = TreeSize(node)[end]
    start = block_index(dims, first.(indices)...)
    stop = block_index(dims, last.(indices)...)
    ContinuousView(node, generateblocks(CartesianIndex(start):CartesianIndex(stop), A), indices, start .- 1)
end
function _spotview(parentdims::Tuple, A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    node = rootnode(A)
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, I...))
    stop = start + oneunit(start)
    ContinuousView(node,
                   generateblocks(SArray{NTuple{N, 2}}(start:stop), A),
                   UnitRange.(I, I.+dims),
                   Tuple(start) .- 1)
end

gettreeview(x::TreeView) = x
gettreeview(x::AbstractTreeArray) = x.tree
for f in (:continuousview, :spotview)
    _f = Symbol(:_, f)
    @eval begin
        @inline function $f(A::Union{AbstractTreeArray, TreeView}, I::Union{Int, AbstractUnitRange, Colon}...)
            @boundscheck checkbounds(A, I...)
            @inbounds $_f(size(A), gettreeview(A), I...)
        end
        @inline function $f(A::Union{AbstractTreeArray, TreeView}, inds::CartesianIndices)
            @boundscheck checkbounds(A, inds)
            @inbounds $_f(size(A), gettreeview(A), inds.indices...)
        end
        @inline function $f(A::Union{AbstractTreeArray, TreeView}, I::CartesianIndex)
            @boundscheck checkbounds(A, I)
            @inbounds $_f(size(A), gettreeview(A), Tuple(I)...)
        end
        @inline function $f(A::PropertyArray{<: Any, <: Any, name}, I...) where {name}
            @boundscheck checkbounds(A, I...)
            @inbounds getproperty($f(A.parent, I...), name)
        end
    end
end

dropleafindex(x::TreeIndex{depth}) where {depth} = TreeIndex(ntuple(i -> x.I[i], Val(depth-1)))
function generateblocks(blockindices, A::TreeView)
    node = rootnode(A)
    nblocks = nleafblocks(node)
    broadcast(blockindices) do i
        @_inline_meta
        blockindex = Tuple(i)
        checkbounds(Bool, CartesianIndices(nblocks), blockindex...) || return null(leaftype(node))
        I = blockindex .* TreeSize(node)[end] # global index
        treeindex = dropleafindex(TreeLinearIndex(A, I...))
        @inbounds rootnode(A[treeindex]) # should be @inbounds?
    end
end

@inline function Base.getindex(x::PropertyArray{<: Any, <: Any, name}, i::BlockLocalIndex) where {name}
    @_propagate_inbounds_meta
    getproperty(x.parent[i], name)
end

@inline function Base.setindex!(x::PropertyArray{<: Any, <: Any, name}, v, i::BlockLocalIndex) where {name}
    @_propagate_inbounds_meta
    allocated = allocate!(x.parent, i)
    set!(allocated, name, v)
    x
end
