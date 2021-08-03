############
# LeafNode #
############

function eachleaf!(f, node::LeafNode)
    @inbounds @simd for i in eachindex(node)
        if isactive(node, i)
            unsafe_setindex!(node, f(unsafe_getindex(node, i)), i)
        end
    end
end

@inline function eachleaf!(f, node::LeafNode, indices::CartesianIndices)
    @boundscheck checkbounds(node, indices)
    @inbounds @simd for cartesian in indices
        I = Tuple(cartesian)
        if isactive(node, I...)
            unsafe_setindex!(node, f(unsafe_getindex(node, I...)), I...)
        end
    end
end

#############################################
# Node/HashNode/DynamicNode/DynamicHashNode #
#############################################

@inline function _eachleaf!(f, node, i)
    @_propagate_inbounds_meta
    if isactive(node, i)
        eachleaf!(f, unsafe_getindex(node, i))
    end
end
function eachleaf!(f, node::Union{Node, HashNode, DynamicNode, DynamicHashNode})
    for i in eachindex(node)
        @inbounds _eachleaf!(f, node, i)
    end
end
function eachleaf_threads!(f, node::Union{Node, HashNode, DynamicNode, DynamicHashNode})
    Threads.@threads for i in eachindex(node)
        @inbounds _eachleaf!(f, node, i)
    end
end

@inline function _eachleaf!(f, node, I, indices)
    @_propagate_inbounds_meta
    dims = totalsize(Base.tail(TreeSize(node)))
    if isactive(node, I...)
        child = unsafe_getindex(node, I...)
        offset = @. (I - 1) * dims
        childinds = CartesianIndex(offset.+1):CartesianIndex(offset.+dims)
        eachleaf!(f, child, (indices ∩ childinds) .- CartesianIndex(offset))
    end
end
function eachleaf!(f, node::Union{Node, HashNode, DynamicNode, DynamicHashNode}, indices::CartesianIndices)
    @boundscheck checkbounds(TreeView(node), indices)
    start = offset_cartesian(node, Tuple(first(indices))...)
    stop = offset_cartesian(node, Tuple(last(indices))...)
    for cartesian in start:stop
        I = Tuple(cartesian)
        @inbounds _eachleaf!(f, node, I, indices)
    end
end
function eachleaf_threads!(f, node::Union{Node, HashNode, DynamicNode, DynamicHashNode}, indices::CartesianIndices) # threads version
    @boundscheck checkbounds(TreeView(node), indices)
    S = TreeSize(node)
    start = offset_cartesian(node, Tuple(first(indices))...)
    stop = offset_cartesian(node, Tuple(last(indices))...)
    Threads.@threads for cartesian in start:stop
        I = Tuple(cartesian)
        @inbounds _eachleaf!(f, node, I, indices)
    end
end

######################
# TreeView/TreeArray #
######################

function eachleaf!(f, A::TreeView)
    if length(A) > THREADS_THRESHOLD
        eachleaf_threads!(f, rootnode(A))
    else
        eachleaf!(f, rootnode(A))
    end
    A
end

_torange(i::Int) = i:i
_torange(i::Union{UnitRange, Colon}) = i
function eachleaf!(f, A::TreeView{<: Any, N}, I::Vararg{Union{Int, UnitRange, Colon}}) where {N}
    indices = CartesianIndices(to_indices(A, map(_torange, I)))
    @boundscheck checkbounds(A, indices)
    @inbounds if length(A) > THREADS_THRESHOLD
        eachleaf_threads!(f, rootnode(A), indices)
    else
        eachleaf!(f, rootnode(A), indices)
    end
    A
end

eachleaf!(f, A::TreeArray) = eachleaf!(f, A.tree)
function eachleaf!(f, A::TreeArray, I...)
    indices = to_indices(A, I)
    @boundscheck checkbounds(A, indices...)
    @inbounds eachleaf!(f, A.tree, indices...)
end
