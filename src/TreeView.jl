struct TreeView{T, N, Tnode <: AbstractNode{<: Any, N}} <: AbstractArray{T, N}
    rootnode::Tnode
end

function TreeView(rootnode::AbstractNode{<: Any, N}) where {N}
    T = leafeltype(rootnode)
    TreeView{T, N, typeof(rootnode)}(rootnode)
end

Base.size(x::TreeView) = totalsize(x.rootnode)

@inline TreeLinearIndex(x::TreeView{<: Any, N}, I::Vararg{Integer, N}) where {N} = TreeLinearIndex(x.rootnode, I...)
@inline TreeCartesianIndex(x::TreeView{<: Any, N}, I::Vararg{Integer, N}) where {N} = TreeCartesianIndex(x.rootnode, I...)

@inline function Base.getindex(x::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds x[index]
end

@inline function Base.setindex!(x::TreeView{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds x[index] = v
end

@inline function isactive(x::TreeView{<: Any, N}, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds isactive(x, index)
end

wrap_treeview(x) = x
wrap_treeview(x::AbstractNode) = TreeView(x)
@generated function Base.getindex(x::TreeView, I::TreeIndex{depth}) where {depth}
    ex = :(x.rootnode)
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

@generated function Base.setindex!(x::TreeView, ::Nothing, I::TreeIndex{depth}) where {depth}
    ex = :(x.rootnode)
    for i in 1:depth
        sym = Symbol(:node, i)
        ex = quote
            $sym = $ex
            isactive($sym, I[$i]) || return x
            $(i == depth ? :($sym[I[$i]] = nothing) : :(unsafe_getindex($sym, I[$i])))
        end
    end
    quote
        @_inline_meta
        @_propagate_inbounds_meta
        $ex
    end
end

@generated function isactive(x::TreeView, I::TreeIndex{depth}) where {depth}
    ex = :(x.rootnode)
    for i in 1:depth
        sym = Symbol(:node, i)
        ex = quote
            $sym = $ex
            isactive($sym, I[$i]) || return false
            $(i == depth ? true : :(unsafe_getindex($sym, I[$i])))
        end
    end
    quote
        @_inline_meta
        @_propagate_inbounds_meta
        $ex
    end
end

# used in ContinuousView
@inline function _setindex!_getleaf(x::TreeView{<: Any, N}, v, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(x, I...)
    index = TreeLinearIndex(x, I...)
    @inbounds _setindex!_getleaf(x, v, index)
end

@generated function _setindex!_getleaf(x::TreeView, v, I::TreeIndex{depth}) where {depth}
    ex = :(x.rootnode)
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


function Base.fill!(x::TreeView, ::Nothing)
    node = x.rootnode
    isnull(node) && return x
    if length(x) > THREADS_THRESHOLD
        fill!(getmask(node), false)
        Threads.@threads for i in eachindex(node)
            @inbounds deactivate!(node[i])
        end
    else
        deactivate!(node)
    end
    x
end

function Base.fill!(A::SubArray{<: Any, <: Any, <: TreeView}, ::Nothing)
    for I in eachindex(A)
        @inbounds A[I] = nothing
    end
    A
end

function nleaves(x::TreeView)
    node = x.rootnode
    if length(x) > THREADS_THRESHOLD
        isnull(node) && return 0
        counts = zeros(Int, Threads.nthreads())
        @inbounds Threads.@threads for i in eachindex(node)
            if isactive(node, i)
                child = unsafe_getindex(node, i)
                counts[Threads.threadid()] += nleaves(child)
            end
        end
        sum(counts)
    else
        nleaves(node)
    end
end
