struct FlatView{T, N, pow, Tnode} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Array{LeafNode{T, N, pow}, N}
    dims::NTuple{N, Int}
end

Base.size(x::FlatView) = x.dims
Base.parent(x::FlatView) = x.parent

@inline function Base.getindex(x::FlatView{<: Any, N, pow}, I::Vararg{Int, N}) where {N, pow}
    @boundscheck checkbounds(x, I...)
    blockindex = @. (I-1) >> pow + 1
    localindex = @. I - (blockindex-1) << pow
    @inbounds begin
        block = x.blocks[blockindex...]
        block[localindex...]
    end
end

@inline function Base.setindex!(x::FlatView{<: Any, N, pow}, v, I::Vararg{Int, N}) where {N, pow}
    @boundscheck checkbounds(x, I...)
    blockindex = @. (I-1) >> pow + 1
    localindex = @. I - (blockindex-1) << pow
    @inbounds begin
        if isassigned(x.blocks, blockindex...)
            block = x.blocks[blockindex...]
            block[localindex...] = v
        else
            leaf = _setindex!_getleaf(TreeView(parent(x)), v, I...)
            x.blocks[blockindex...] = leaf
        end
    end
    x
end

function FlatView(A::TreeView{<: Any, N}, I::Vararg{Union{Int, UnitRange}, N}) where {N}
    @boundscheck checkbounds(A, I...)
    node = A.rootnode
    dims = map(length, I)
    p = leafpower(Powers(node))
    start = CartesianIndex(block_index(p, first.(I)...))
    stop = CartesianIndex(block_index(p, last.(I)...))
    flat = FlatView(node, Array{leaftype(node)}(undef, size(start:stop)), dims)
    setleaves!(flat, A, Coordinate(I))
    flat
end

dropleafindex(x::TreeLinearIndex{depth}) where {depth} = TreeLinearIndex(ntuple(i -> x.I[i], Val(depth-1)))
dropleafindex(x::TreeCartesianIndex{depth}) where {depth} = TreeCartesianIndex(ntuple(i -> x.I[i], Val(depth-1)))
function setleaves!(flat::FlatView{<: Any, <: Any, p}, A::TreeView, inds) where {p}
    @inbounds @simd for i in eachindex(inds)
        I = inds[i]
        blockindex = block_index(p, I...)
        treeindex = dropleafindex(TreeLinearIndex(A, I...))
        if !isassigned(flat.blocks, blockindex...) && isactive(A, treeindex)
            flat.blocks[blockindex...] = (A[treeindex]).rootnode
        end
    end
    flat
end

@inline block_index(p::Int, I::Int...) = @. (I-1) >> p + 1
@inline function block_local_index(p::Int, I::Int...)
    blockindex = block_index(p, I...)
    localindex = @. I - (blockindex-1) << p
    blockindex, localindex
end
