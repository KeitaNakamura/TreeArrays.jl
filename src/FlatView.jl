struct FlatView{T, N, pow, Tnode} <: AbstractArray{T, N}
    parent::Tnode
    blocks::Array{Leaf{T, N, pow}, N}
end

Base.size(x::FlatView{<: Any, <: Any, pow}) where {pow} = .<<(size(x.blocks), pow)

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

function _setleaves!(A, offset::CartesianIndex{N}, node::AbstractNode{<: Leaf, N}, ::Powers{()}) where {N}
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
