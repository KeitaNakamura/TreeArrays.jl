struct FlatView{T, N, pow, Tnode <: AbstractNode{<: Any, N}, Tindices <: Tuple} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Array{LeafNode{T, N, pow}, N}
    indices::Tindices
end

Base.size(x::FlatView) = map(length, x.indices)
Base.parent(x::FlatView) = x.parent

function blockoffset(x::FlatView{<: Any, <: Any, p}) where {p}
    block_index(p, first.(x.indices)...) .- 1
end

@inline function Base.getindex(x::FlatView{<: Any, N, pow}, I::Vararg{Int, N}) where {N, pow}
    @boundscheck checkbounds(x, I...)
    @inbounds I = Coordinate(x.indices)[I...]
    blockindex, localindex = block_local_index(x, I...)
    @inbounds begin
        block = x.blocks[blockindex]
        block[localindex]
    end
end

@inline function Base.setindex!(x::FlatView{<: Any, N, pow}, v, I::Vararg{Int, N}) where {N, pow}
    @boundscheck checkbounds(x, I...)
    @inbounds I = Coordinate(x.indices)[I...]
    blockindex, localindex = block_local_index(x, I...)
    @inbounds begin
        if isassigned(x.blocks, blockindex...)
            block = x.blocks[blockindex]
            block[localindex] = v
        else
            leaf = _setindex!_getleaf(TreeView(parent(x)), v, I...)
            x.blocks[blockindex] = leaf
        end
    end
    x
end

_to_indices(A::AbstractArray, I) = map(i -> Base.unalias(A, i), to_indices(A, axes(A), I))
function FlatView(A::TreeView{<: Any, N}, I::Vararg{Union{Int, UnitRange, Colon}, N}) where {N}
    indices = _to_indices(A, I)
    @boundscheck checkbounds(A, indices...)
    node = A.rootnode
    p = leafpower(Powers(node))
    start = CartesianIndex(block_index(p, first.(indices)...))
    stop = CartesianIndex(block_index(p, last.(indices)...))
    flat = FlatView(node, Array{leaftype(node)}(undef, size(start:stop)), indices)
    setleaves!(flat, A)
    flat
end

dropleafindex(x::TreeLinearIndex{depth}) where {depth} = TreeLinearIndex(ntuple(i -> x.I[i], Val(depth-1)))
dropleafindex(x::TreeCartesianIndex{depth}) where {depth} = TreeCartesianIndex(ntuple(i -> x.I[i], Val(depth-1)))
function setleaves!(flat::FlatView{<: Any, <: Any, p}, A::TreeView) where {p}
    blocks = flat.blocks
    @inbounds for i in CartesianIndices(blocks)
        blockindex = Tuple(i)
        I = (blockindex .+ blockoffset(flat)) .<< p # global index
        treeindex = dropleafindex(TreeLinearIndex(A, I...))
        if isactive(A, treeindex)
            blocks[blockindex...] = (A[treeindex]).rootnode
        end
    end
    flat
end

# cartesian
@inline block_index(p::Int, I::Int...) = @. (I-1) >> p + 1
@inline function block_local_index(p::Int, I::Int...)
    blockindex = block_index(p, I...)
    localindex = @. I - (blockindex-1) << p
    blockindex, localindex
end

# linear
@inline function block_index(x::FlatView{<: Any, <: Any, p}, I::Int...) where {p}
    Base._sub2ind(size(x.blocks), (block_index(p, I...) .- blockoffset(x))...)
end
@inline function block_local_index(x::FlatView{<: Any, <: Any, p}, I::Int...) where {p}
    blockindex, localindex = block_local_index(p, I...)
    blocklinear = Base._sub2ind(size(x.blocks), (blockindex .- blockoffset(x))...)
    locallinear = sub2ind(p, localindex...)
    blocklinear, locallinear
end
