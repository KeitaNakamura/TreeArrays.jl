abstract type DenseNode{T, N, p} <: AbstractNode{T, N, p} end

Base.IndexStyle(::Type{<: DenseNode}) = IndexLinear()

@inline function Base.getindex(x::DenseNode, i::Int)
    @boundscheck checkbounds(x, i)
    # Sometimes `i` is inactive, but corresponding data is not null
    # because mask is only set to `false` when the entry is deactivated (as long as call `cleanup!`)
    # This should be very careful because returned child node can be unexpectedly changed.
    @inbounds isnull(x) ? null(childtype(x)) : unsafe_getindex(x, i)
end

@inline function Base.setindex!(x::DenseNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    # The mask is activated in MaskedDenseArray.
    # Allowing mask to be active only when setting corresponding data.
    # This ensures that when mask is active, its value is always valid
    # Similarly if null at `i`, then corresponding mask is always false (see also `delete!(node, i)`)
    isnull(v) && throw(ArgumentError("trying to set null node, call `delete!(node, i)` instead"))
    @inbounds x.data[i] = v
    x
end

@inline function Base.setindex!(x::DenseNode, ::Nothing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        # Make mask false at i (don't delete corresponding data)
        # The children are also deactivated
        if isactive(x, i)
            x.data[i] = nothing # make `mask` `false` at `i`
            deactivate!(unsafe_getindex(x, i))
        end
    end
    x
end

@inline function deactivate!(x::DenseNode)
    isnull(x) && return x
    fill!(getmask(x), false)
    for i in eachindex(x)
        @inbounds deactivate!(unsafe_getindex(x, i))
    end
    x
end

function Base.delete!(x::DenseNode, i)
    @boundscheck checkbounds(x, i)
    @inbounds begin
        # only this case allows to set null node in `x`
        x.data[i] = nothing # make mask false
        unsafe_setindex!(x, null(childtype(x)), i)
    end
    x
end

function allocate!(x::DenseNode{T}, i::Int) where {T}
    @boundscheck checkbounds(x, i)
    @inbounds begin
        childnode = unsafe_getindex(x, i)
        if isnull(childnode) # && !isactive(x, i)
            childnode = T()
        end
        x[i] = childnode # activated in setindex!
    end
    Allocated(x, i)
end

isallocated(x::DenseNode, i::Int) = unsafe_getindex(x, i) !== null(childtype(x))


struct Node{T <: AbstractNode, N, p} <: DenseNode{T, N, p}
    data::MaskedDenseArray{T, N}
    Node{T, N, p}(data) where {T, N, p} = new(data)
    Node{T, N, p}(::UndefInitializer) where {T, N, p} = new()
end

function Node{T, N, p}() where {T, N, p}
    dims = size(Node{T, N, p})
    data = MaskedDenseArray([null(T) for I in CartesianIndices(dims)])
    Node{T, N, p}(data)
end

Base.size(x::Node) = size(typeof(x))


struct DynamicNode{T <: AbstractNode, N} <: DenseNode{T, N, Dynamic()}
    data::MaskedDenseArray{T, N}
    dims::NTuple{N, Int}
    DynamicNode{T, N}(data, dims) where {T, N} = new(data, dims)
    DynamicNode{T, N}(::UndefInitializer) where {T, N} = new()
end

function DynamicNode{T, N}(dims::Int...) where {T, N}
    data = MaskedDenseArray([null(T) for I in CartesianIndices(dims)])
    DynamicNode{T, N}(data, dims)
end

Base.size(x::DynamicNode) = x.dims
