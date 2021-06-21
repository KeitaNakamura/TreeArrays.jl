abstract type AbstractNode{T, L} <: AbstractVector{T} end

Base.length(::Type{<: AbstractNode{T, L}}) where {T, L} = L
Base.length(x::AbstractNode) = length(typeof(x))
Base.size(::Type{<: AbstractNode{T, L}}) where {T, L} = (L,)
Base.size(x::AbstractNode) = size(typeof(x))

get_prev(x::AbstractNode) = isassigned(x.prev) ? x.prev[] : nothing
set_prev!(x::AbstractNode, v) = (x.prev[] = v; x)
get_next(x::AbstractNode) = isassigned(x.next) ? x.next[] : nothing
set_next!(x::AbstractNode, v) = (x.next[] = v; x)

isactive(x::AbstractNode, i::Int) = (@_propagate_inbounds_meta; x.mask[i])
allactive(x::AbstractNode) = all(x.mask)
anyactive(x::AbstractNode) = any(x.mask)

Base.isassigned(x::AbstractNode, i::Int...) = (@_propagate_inbounds_meta; x.mask[i...])

checkmask(::Type{Bool}, x::AbstractNode, i) = isactive(x, i) # checkbounds as well
checkmask(x::AbstractNode, i) = checkmask(Bool, x, i) ? nothing : error("access to unactivated element")
