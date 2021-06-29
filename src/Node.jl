struct Node{T <: AbstractNode, N, pow} <: AbstractNode{T, N, pow}
    data::MaskedArray{T, N}
    Node{T, N, pow}(data) where {T, N, pow} = new(data)
    Node{T, N, pow}(::Nothing) where {T, N, pow} = new()
end

function Node{T, N, pow}() where {T, N, pow}
    dims = size(Node{T, N, pow})
    data = MaskedArray([null(T) for I in CartesianIndices(dims)])
    Node{T, N, pow}(data)
end

@pure childtype(::Type{<: Node{T}}) where {T} = T
@pure leaftype(::Type{<: Node{T}}) where {T} = leaftype(T)
@pure leafeltype(::Type{<: Node{T}}) where {T} = leafeltype(T)

Base.IndexStyle(::Type{<: Node}) = IndexLinear()

@inline function Base.getindex(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    # Sometimes `i` is inactive, but corresponding data is not null
    # because mask is only set to `false` when the entry is deactivated (as long as call `cleanup!`)
    # This should be very careful because returned child node can be unexpectedly changed.
    @inbounds isnull(x) ? null(childtype(x)) : unsafe_getindex(x, i)
end

@inline function Base.setindex!(x::Node, v, i::Int)
    @boundscheck checkbounds(x, i)
    # The mask is activated in MaskedArray.
    # Allowing mask to be active only when setting corresponding data.
    # This ensures that when mask is active, its value is always valid
    # Similarly if null at `i`, then corresponding mask is always false (see also `delete!(node, i)`)
    isnull(v) && throw(ArgumentError("trying to set null node, call `delete!(node, i)` instead"))
    @inbounds x.data[i] = v
    x
end

@inline function Base.setindex!(x::Node, ::Nothing, i::Int)
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

@inline function unsafe_getindex(x::Node, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_getindex(x.data, i)
end

@inline function unsafe_setindex!(x::Node, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds unsafe_setindex!(x.data, v, i)
end

@inline function deactivate!(x::Node)
    isnull(x) && return x
    fillmask!(x, false)
    for i in eachindex(x)
        @inbounds deactivate!(unsafe_getindex(x, i))
    end
    x
end

function Base.delete!(x::Node, i...)
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        # only this case allows to set null node in `x`
        x.data[i] = nothing # make mask false
        unsafe_setindex!(x, null(childtype(x)), i...)
    end
    x
end

function allocate!(x::Node{T}, i...) where {T}
    @boundscheck checkbounds(x, i...)
    @inbounds begin
        childnode = unsafe_getindex(x, i...)
        if isnull(childnode) # && !isactive(x, i)
            childnode = T()
            x[i...] = childnode # activated in setindex!
        end
    end
    childnode
end

function cleanup!(x::Node)
    @inbounds for i in eachindex(x)
        if isactive(x, i)
            # if `i` is active, then child node is always not null
            childnode = unsafe_getindex(x, i)
            cleanup!(childnode)
            !anyactive(childnode) && delete!(x, i)
        else
            delete!(x, i)
        end
    end
    x
end
