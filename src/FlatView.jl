struct FlatView{T, N, pow, Tnode} <: AbstractArray{T, N}
    parent::Tnode # needed for new node allocation
    blocks::Array{LeafNode{T, N, pow}, N}
end

Base.size(x::FlatView{<: Any, <: Any, pow}) where {pow} = .<<(size(x.blocks), pow)
Base.parent(x::FlatView) = x.parent

function Base.isassigned(x::FlatView, i::Int...)
    try
        x[i...]
    catch
        return false
    end
    true
end

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

@generated function FlatView(node::AbstractNode{<: Any, N}) where {pows, N}
    pows = Tuple(Powers(node))
    n = 1 << pows[end]
    nblocks = 1 << sum(pows[1:end-1])
    block_sizes = fill(nblocks, N)
    T = leaftype(node)
    quote
        A = FlatView(node, Array{$T}(undef, $(block_sizes...)))
        setleaves!(A.blocks, zero(CartesianIndex{N}), node)
        A
    end
end

function _setleaves!(A, offset::CartesianIndex{N}, node::AbstractNode{<: LeafNode, N}, ::Powers{()}) where {N}
    @inbounds for i in eachindex(node)
        if isactive(node, i)
            I = CartesianIndex(ind2sub(node, i))
            A[offset + I] = node[i]
        end
    end
    A
end

function _setleaves!(A, offset::CartesianIndex{N}, node::AbstractNode{<: Any, N}, P::Powers{pows}) where {N, pows}
    n = 1 << sum(pows)
    @inbounds for i in eachindex(node)
        if isactive(node, i)
            I = CartesianIndex(ind2sub(node, i))
            _setleaves!(A, offset + n*(I-oneunit(I)), node[i], Base.tail(P))
        end
    end
    A
end
@generated function setleaves!(A, offset::CartesianIndex{N}, node::AbstractNode{<: Any, N}) where {N}
    pows = Tuple(Powers(node))
    quote
        _setleaves!(A, offset, node, Powers($(pows[2:end-1]...)))
        A
    end
end
