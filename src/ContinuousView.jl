struct ContinuousView{T, N, p, Tnode <: AbstractNode{<: Any, N}, Tindices <: Tuple, Tblocks <: AbstractArray{LeafNode{T, N, p}, N}} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Tblocks
    indices::Tindices
end

Base.size(x::ContinuousView) = map(length, x.indices)
Base.parent(x::ContinuousView) = x.parent

function blockoffset(x::ContinuousView)
    block_index(TreeSize(x.parent)[end], first.(x.indices)...) .- 1
end

@inline function Base.getindex(x::ContinuousView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    @inbounds I = Coordinate(x.indices)[I...]
    blockindex, localindex = block_local_index(x, I...)
    @inbounds begin
        block = x.blocks[blockindex]
        block[localindex]
    end
end

@inline function Base.setindex!(x::ContinuousView{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    @inbounds I = Coordinate(x.indices)[I...]
    blockindex, localindex = block_local_index(x, I...)
    @inbounds begin
        block = x.blocks[blockindex]
        if isnull(block)
            leaf = _setindex!_getleaf(TreeView(parent(x)), v, I...)
            x.blocks[blockindex] = leaf
        else
            block[localindex] = v
        end
    end
    x
end

@inline function ContinuousView(A::TreeView{<: Any, N}, I::Vararg{Union{Int, UnitRange, Colon}, N}) where {N}
    indices = to_indices(A, I)
    @boundscheck checkbounds(A, indices...)
    node = A.rootnode
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, first.(indices)...))
    stop = CartesianIndex(block_index(dims, last.(indices)...))
    ContinuousView(node, generateblocks(start:stop, A), indices)
end
@inline function SpotView(A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(A, I...)
    node = A.rootnode
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, I...))
    stop = start + oneunit(start)
    ContinuousView(node,
                   generateblocks(SArray{NTuple{N, 2}}(start:stop), A),
                   @. UnitRange(I, I+dims-1))
end

dropleafindex(x::TreeIndex{depth}) where {depth} = TreeIndex(ntuple(i -> x.I[i], Val(depth-1)))
function generateblocks(blockindices, A::TreeView)
    map(blockindices) do i
        blockindex = Tuple(i)
        I = blockindex .* TreeSize(A.rootnode)[end] # global index
        treeindex = dropleafindex(TreeLinearIndex(A, I...))
        @inbounds (A[treeindex]).rootnode # should be @inbounds?
    end
end

# cartesian
@inline block_index(dims::Tuple, I::Int...) = @. div(I-1, dims) + 1
@inline function block_local_index(dims::Tuple, I::Int...)
    blockindex = block_index(dims, I...)
    localindex = @. I - (blockindex-1) * dims
    blockindex, localindex
end

# linear
@inline function block_index(x::ContinuousView, I::Int...)
    dims = TreeSize(x.parent)[end]
    Base._sub2ind(size(x.blocks), (block_index(dims, I...) .- blockoffset(x))...)
end
@inline function block_local_index(x::ContinuousView, I::Int...)
    dims = TreeSize(x.parent)[end]
    blockindex, localindex = block_local_index(dims, I...)
    blocklinear = Base._sub2ind(size(x.blocks), (blockindex .- blockoffset(x))...)
    locallinear = Base._sub2ind(dims, localindex...)
    blocklinear, locallinear
end
