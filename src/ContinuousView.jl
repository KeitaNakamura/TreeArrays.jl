struct ContinuousView{T, N, p, Tnode <: AbstractNode{<: Any, N}, Tblocks <: AbstractArray{<: AbstractLeafNode{T, N, p}, N}, Tindices <: Tuple} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Tblocks
    indices::Tindices
end

Base.size(x::ContinuousView) = map(length, x.indices)
Base.axes(x::ContinuousView) = Base.IdentityUnitRange.(x.indices)
Base.parent(x::ContinuousView) = x.parent

Base.propertynames(x::ContinuousView{<: Any, <: Any, <: Any, <: Any, <: AbstractArray{<: StructLeafNode}}) = (:parent, :blocks, :indices, fieldnames(eltype(x))...)
function Base.getproperty(x::ContinuousView{<: Any, N, <: Any, <: Any, <: AbstractArray{<: StructLeafNode}}, name::Symbol) where {N}
    name == :parent && return getfield(x, :parent)
    name == :blocks && return getfield(x, :blocks)
    name == :indices && return getfield(x, :indices)
    T = fieldtype(leafeltype(parent(x)), name)
    PropertyArray{T, N}(x, name)
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
@inline function continuousview(A::TreeView{<: Any, N}, I::Vararg{Union{Int, AbstractUnitRange, Colon}, N}) where {N}
    indices = to_indices(A, I)
    @boundscheck checkbounds(A, indices...)
    node = A.rootnode
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, first.(indices)...))
    stop = CartesianIndex(block_index(dims, last.(indices)...))
    ContinuousView(node, generate_offset_blocks(start:stop, A), indices)
end
@inline function spotview(A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(A, I...)
    node = A.rootnode
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, I...))
    stop = start + oneunit(start)
    ContinuousView(node,
                   generate_offset_blocks(SArray{NTuple{N, 2}}, start:stop, A),
                   @. UnitRange(I, I+dims))
end
@inline function blockview(A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    node = A.rootnode
    dims = TreeSize(node)[end]
    index = CartesianIndex(@. dims*(I-1) + 1)
    blockindex = CartesianIndex(I)
    ContinuousView(node,
                   generate_offset_blocks(SArray{NTuple{N, 1}}, blockindex:blockindex, A),
                   @.(UnitRange($Tuple(index), $Tuple(index)+dims-1)))
end
@inline function blockaroundview(A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    node = A.rootnode
    dims = TreeSize(node)[end]
    index = CartesianIndex(@. dims*(I-1) + 1)
    range = dims .÷ 2
    indices = @. UnitRange($Tuple(index)-range, $Tuple(index)+dims-1+range)
    ContinuousView(node,
                   generate_offset_blocks(SArray{NTuple{N, 3}}, CartesianIndex(I.-1):CartesianIndex(I.+1), A),
                   (CartesianIndices(indices) ∩ CartesianIndices(A)).indices)
end

for f in (:continuousview, :spotview, :blockview, :blockaroundview)
    @eval begin
        @inline function $f(A::AbstractTreeArray, I::Union{Int, AbstractUnitRange, Colon}...)
            @_propagate_inbounds_meta
            $f(A.tree, I...)
        end
        @inline function $f(A::AbstractTreeArray, inds::CartesianIndices)
            @_propagate_inbounds_meta
            $f(A.tree, inds.indices...)
        end
        @inline function $f(A::PropertyArray, I::Union{Int, AbstractUnitRange, Colon}...)
            @_propagate_inbounds_meta
            getproperty($f(A.parent, I...), A.name)
        end
    end
end

dropleafindex(x::TreeIndex{depth}) where {depth} = TreeIndex(ntuple(i -> x.I[i], Val(depth-1)))
function generateblocks(blockindices, A::TreeView)
    node = A.rootnode
    blksize = leafblocksize(node)
    broadcast(blockindices) do i
        blockindex = Tuple(i)
        checkbounds(Bool, CartesianIndices(blksize), blockindex...) || return null(leaftype(node))
        I = blockindex .* TreeSize(node)[end] # global index
        treeindex = dropleafindex(TreeLinearIndex(A, I...))
        @inbounds (A[treeindex]).rootnode # should be @inbounds?
    end
end
