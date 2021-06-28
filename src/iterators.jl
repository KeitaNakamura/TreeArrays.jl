function _eachleaf!(f, node::LeafNode)
    @inbounds @simd for i in eachindex(node)
        if isactive(node, i)
            unsafe_setindex!(node, f(unsafe_getindex(node, i)), i)
        end
    end
end
function _eachleaf!(f, node::Node)
    @inbounds for i in eachindex(node)
        if isactive(node, i)
            _eachleaf!(f, unsafe_getindex(node, i))
        end
    end
end

eachleaf!(f, node::LeafNode) = _eachleaf!(f, node)
function eachleaf!(f, node::Node)
    @inbounds Threads.@threads for i in eachindex(node)
        if isactive(node, i)
            _eachleaf!(f, unsafe_getindex(node, i))
        end
    end
end
