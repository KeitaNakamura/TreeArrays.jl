struct TreeView{T, N, Tnode <: AbstractNode{<: Any, N}} <: AbstractArray{T, N}
    node::Tnode
end

function TreeView(node::AbstractNode{<: Any, N}) where {N}
    T = leafeltype(node)
    TreeView{T, N, typeof(node)}(node)
end

Base.size(x::TreeView{<: Any, N}) where {N} = (n = 1 << sum(Powers(x.node)); ntuple(d -> n, Val(N)))

function Base.isassigned(x::TreeView, i::Int...)
    try
        x[i...]
    catch
        return false
    end
    true
end

TreeLinearIndex(x::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N} = TreeLinearIndex(Powers(x.node), I...)
TreeCartesianIndex(x::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N} = TreeCartesianIndex(Powers(x.node), I...)

function Base.getindex(x::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds x[index]
end

function Base.setindex!(x::TreeView{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds x[index] = v
end

wrap_treeview(x) = x
wrap_treeview(x::AbstractNode) = TreeView(x)
@generated function Base.getindex(x::TreeView, I::TreeIndex{depth}) where {depth}
    ex = :(x.node)
    for i in 1:depth
        ex = :($ex[I[$i]])
    end
    quote
        @_inline_meta
        @_propagate_inbounds_meta
        wrap_treeview($ex)
    end
end

@inline function Base.setindex!(x::TreeView, v, I::TreeIndex)
    @_propagate_inbounds_meta
    _setindex!_getleaf(x, v, I)
    x
end


# used in FlatView
@inline function _setindex!_getleaf(x::TreeView{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds _setindex!_getleaf(x, v, index)
end

@generated function _setindex!_getleaf(x::TreeView, v, I::TreeIndex{depth}) where {depth}
    ex = :(x.node)
    for i in 1:depth
        if i == depth
            ex = :(setindex!($ex, v, I[$i]))
        else
            ex = :(allocate!($ex, I[$i]))
        end
    end
    quote
        @_inline_meta
        @_propagate_inbounds_meta
        $ex
    end
end
