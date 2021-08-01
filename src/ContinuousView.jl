struct ContinuousView{T, N, p, Tnode <: AbstractNode{<: Any, N}, Tblocks <: AbstractArray{<: AbstractLeafNode{T, N, p}, N}, Tindices <: Tuple} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Tblocks
    indices::Tindices
end

Base.size(x::ContinuousView) = map(length, x.indices)
Base.axes(x::ContinuousView) = Base.IdentityUnitRange.(x.indices)
Base.parent(x::ContinuousView) = x.parent
rootnode(x::ContinuousView) = parent(x)

Base.propertynames(x::ContinuousView{<: Any, <: Any, <: Any, <: Any, <: AbstractArray{<: StructLeafNode}}) = (:parent, :blocks, :indices, fieldnames(eltype(x))...)
@inline function Base.getproperty(x::ContinuousView{<: Any, N, <: Any, <: Any, <: AbstractArray{<: StructLeafNode}}, name::Symbol) where {N}
    name == :parent && return getfield(x, :parent)
    name == :blocks && return getfield(x, :blocks)
    name == :indices && return getfield(x, :indices)
    T = fieldtype(leafeltype(parent(x)), name)
    PropertyArray{T, N, name}(x)
end

block_local_index(x::ContinuousView{<: Any, N}, I::Vararg{Int, N}) where {N} =
    block_local_index(TreeSize(parent(x))[end], I...)
for f in (:(Base.getindex), :isactive, :allocate!)
    @eval @inline function $f(x::ContinuousView{<: Any, N}, I::Vararg{Int, N}) where {N}
        @boundscheck checkbounds(x, I...)
        blockindex, localindex = block_local_index(x, I...)
        @inbounds begin
            block = x.blocks[blockindex...]
            $f(block, localindex...)
        end
    end
end

@inline function Base.setindex!(x::ContinuousView{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    blockindex, localindex = block_local_index(x, I...)
    @inbounds begin
        block = x.blocks[blockindex...]
        if isnull(block)
            leaf = _setindex!_getleaf(TreeView(parent(x)), v, I...)
            x.blocks[blockindex...] = leaf
        else
            block[localindex...] = v
        end
    end
    x
end

generate_offset_blocks(blockindices::CartesianIndices, A) = OffsetArray(generateblocks(blockindices, A), blockindices)
generate_offset_blocks(SA, blockindices::CartesianIndices, A) = OffsetArray(generateblocks(SA(blockindices), A), blockindices)
function _continuousview(parentdims::Tuple, A::TreeView{<: Any, N}, I::Vararg{Union{Int, AbstractUnitRange, Colon}, N}) where {N}
    indices = to_indices(A, I)
    node = rootnode(A)
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, first.(indices)...))
    stop = CartesianIndex(block_index(dims, last.(indices)...))
    ContinuousView(node, generate_offset_blocks(start:stop, A), indices)
end
function _spotview(parentdims::Tuple, A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    node = rootnode(A)
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, I...))
    stop = start + oneunit(start)
    ContinuousView(node,
                   generate_offset_blocks(SArray{NTuple{N, 2}}, start:stop, A),
                   @. UnitRange(I, I+dims))
end
function _blockview(parentdims::Tuple, A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    node = rootnode(A)
    dims = TreeSize(node)[end]
    index = CartesianIndex(@. dims*(I-1) + 1)
    blockindex = CartesianIndex(I)
    indices = @. UnitRange($Tuple(index), $Tuple(index)+dims-1)
    ContinuousView(node,
                   generate_offset_blocks(SArray{NTuple{N, 1}}, blockindex:blockindex, A),
                   (CartesianIndices(indices) ∩ CartesianIndices(parentdims)).indices)
end
function _blockaroundview(parentdims::Tuple, A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    node = rootnode(A)
    dims = TreeSize(node)[end]
    index = CartesianIndex(@. dims*(I-1) + 1)
    range = dims .÷ 2
    indices = @. UnitRange($Tuple(index)-range, $Tuple(index)+dims-1+range)
    ContinuousView(node,
                   generate_offset_blocks(SArray{NTuple{N, 3}}, CartesianIndex(I.-1):CartesianIndex(I.+1), A),
                   (CartesianIndices(indices) ∩ CartesianIndices(parentdims)).indices)
end

gettreeview(x::TreeView) = x
gettreeview(x::AbstractTreeArray) = x.tree
for f in (:continuousview, :spotview, :blockview, :blockaroundview)
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
