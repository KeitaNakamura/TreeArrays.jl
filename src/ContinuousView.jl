struct ContinuousView{T, N, p, Tnode <: AbstractNode{<: Any, N}, Tindices <: Tuple, Tblocks <: AbstractArray{LeafNode{T, N, p}, N}} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Tblocks
    indices::Tindices
end

Base.size(x::ContinuousView) = map(length, x.indices)
Base.parent(x::ContinuousView) = x.parent

Base.propertynames(x::ContinuousView) = (:parent, :blocks, :indices, fieldnames(eltype(x))...)
function Base.getproperty(x::ContinuousView{<: Any, N}, name::Symbol) where {N}
    name == :parent && return getfield(x, :parent)
    name == :blocks && return getfield(x, :blocks)
    name == :indices && return getfield(x, :indices)
    T = fieldtype(leafeltype(parent(x)), name)
    PropertyArray{T, N}(x, name)
end

function blockoffset(x::ContinuousView)
    block_index(TreeSize(parent(x))[end], first.(x.indices)...) .- 1
end

for f in (:(Base.getindex), :isactive, :allocate!)
    @eval @inline function $f(x::ContinuousView{<: Any, N}, I::Vararg{Int, N}) where {N}
        @boundscheck checkbounds(x, I...)
        @inbounds I = Coordinate(x.indices)[I...]
        blockindex, localindex = block_local_index(x, I...)
        @inbounds begin
            block = x.blocks[blockindex]
            $f(block, localindex)
        end
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

@inline function continuousview(A::TreeView{<: Any, N}, I::Vararg{Union{Int, AbstractUnitRange, Colon}, N}) where {N}
    indices = to_indices(A, I)
    @boundscheck checkbounds(A, indices...)
    node = A.rootnode
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, first.(indices)...))
    stop = CartesianIndex(block_index(dims, last.(indices)...))
    ContinuousView(node, generateblocks(start:stop, A), indices)
end
@inline function spotview(A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(A, I...)
    node = A.rootnode
    dims = TreeSize(node)[end]
    start = CartesianIndex(block_index(dims, I...))
    stop = start + oneunit(start)
    ContinuousView(node,
                   generateblocks(SArray{NTuple{N, 2}}(start:stop), A),
                   @. UnitRange(I, I+dims))
end
@inline function blockview(A::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    node = A.rootnode
    dims = TreeSize(node)[end]
    index = CartesianIndex(@. dims*(I-1) + 1)
    blockindex = CartesianIndex(I)
    ContinuousView(node,
                   generateblocks(SArray{NTuple{N, 1}}(blockindex:blockindex), A),
                   @. UnitRange($Tuple(index), $Tuple(index)+dims-1))
end

for f in (:continuousview, :spotview, :blockview)
    @eval begin
        @inline function $f(A::TreeArray, I::Union{Int, AbstractUnitRange, Colon}...)
            @_propagate_inbounds_meta
            $f(A.tree, I...)
        end
        @inline function $f(A::TreeArray, inds::CartesianIndices)
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
    map(blockindices) do i
        blockindex = Tuple(i)
        I = blockindex .* TreeSize(A.rootnode)[end] # global index
        treeindex = dropleafindex(TreeLinearIndex(A, I...))
        @inbounds (A[treeindex]).rootnode # should be @inbounds?
    end
end

# linear
@inline function block_index(x::ContinuousView, I::Int...)
    dims = TreeSize(parent(x))[end]
    Base._sub2ind(size(x.blocks), (block_index(dims, I...) .- blockoffset(x))...)
end
@inline function block_local_index(x::ContinuousView, I::Int...)
    dims = TreeSize(parent(x))[end]
    blockindex, localindex = block_local_index(dims, I...)
    blocklinear = Base._sub2ind(size(x.blocks), (blockindex .- blockoffset(x))...)
    locallinear = Base._sub2ind(dims, localindex...)
    blocklinear, locallinear
end
