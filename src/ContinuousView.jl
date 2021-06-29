struct ContinuousView{T, N, pow, Tnode <: AbstractNode{<: Any, N}, Tindices <: Tuple, Tblocks <: AbstractArray{LeafNode{T, N, pow}, N}} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Tblocks
    indices::Tindices
end

Base.size(x::ContinuousView) = map(length, x.indices)
Base.parent(x::ContinuousView) = x.parent

function blockoffset(x::ContinuousView{<: Any, <: Any, p}) where {p}
    block_index(p, first.(x.indices)...) .- 1
end

@inline function Base.getindex(x::ContinuousView{<: Any, N, pow}, I::Vararg{Int, N}) where {N, pow}
    @boundscheck checkbounds(x, I...)
    @inbounds I = Coordinate(x.indices)[I...]
    blockindex, localindex = block_local_index(x, I...)
    @inbounds begin
        block = x.blocks[blockindex]
        block[localindex]
    end
end

@inline function Base.setindex!(x::ContinuousView{<: Any, N, pow}, v, I::Vararg{Int, N}) where {N, pow}
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
    p = Powers(node)[end]
    start = CartesianIndex(block_index(p, first.(indices)...))
    stop = CartesianIndex(block_index(p, last.(indices)...))
    ContinuousView(node, generateblocks(start:stop, A), indices)
end
@inline function SpotView(A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(A, I...)
    node = A.rootnode
    p = Powers(node)[end]
    start = CartesianIndex(block_index(p, I...))
    stop = start + oneunit(start)
    ContinuousView(node,
                   generateblocks(SArray{NTuple{N, 2}}(start:stop), A),
                   @. UnitRange(I, I + (1 << p) -1))
end

dropleafindex(x::TreeIndex{depth}) where {depth} = TreeIndex(ntuple(i -> x.I[i], Val(depth-1)))
function generateblocks(blockindices, A::TreeView)
    map(blockindices) do i
        blockindex = Tuple(i)
        I = blockindex .<< Powers(A)[end] # global index
        treeindex = dropleafindex(TreeLinearIndex(A, I...))
        (A[treeindex]).rootnode # should be @inbounds?
    end
end

# cartesian
@inline block_index(p::Int, I::Int...) = @. (I-1) >> p + 1
@inline function block_local_index(p::Int, I::Int...)
    blockindex = block_index(p, I...)
    localindex = @. I - (blockindex-1) << p
    blockindex, localindex
end

# linear
@inline function block_index(x::ContinuousView{<: Any, <: Any, p}, I::Int...) where {p}
    Base._sub2ind(size(x.blocks), (block_index(p, I...) .- blockoffset(x))...)
end
@inline function block_local_index(x::ContinuousView{<: Any, <: Any, p}, I::Int...) where {p}
    blockindex, localindex = block_local_index(p, I...)
    blocklinear = Base._sub2ind(size(x.blocks), (blockindex .- blockoffset(x))...)
    locallinear = sub2ind(p, localindex...)
    blocklinear, locallinear
end
