abstract type AbstractNode{T, N, pow} <: AbstractArray{T, N} end

@pure Base.length(::Type{T}) where {T <: AbstractNode} = prod(size(T))
@pure Base.size(::Type{<: AbstractNode{T, N, pow}}) where {T, N, pow} = ntuple(d -> 1 << pow, Val(N))

Base.length(x::AbstractNode) = length(typeof(x))
Base.size(x::AbstractNode) = size(typeof(x))

childtype(x::AbstractNode) = childtype(typeof(x))
leafeltype(x::AbstractNode) = leafeltype(typeof(x))

isactive(x::AbstractNode, i...) = (@_propagate_inbounds_meta; x.mask[i...])
allactive(x::AbstractNode) = all(x.mask)
anyactive(x::AbstractNode) = any(x.mask)

Base.isassigned(x::AbstractNode, i::Int...) = x.mask[i...]

checkmask(::Type{Bool}, x::AbstractNode, i...) = (@_propagate_inbounds_meta; isactive(x, i...)) # checkbounds as well
checkmask(x::AbstractNode, i...) = (@_propagate_inbounds_meta; checkmask(Bool, x, i...) ? nothing : error("access to unactivated element"))


struct Powers{pows}
    function Powers{pows}() where {pows}
        new{pows::Tuple{Vararg{Int}}}()
    end
end
@pure Powers(p::Tuple{Vararg{Int}}) = Powers{p}()

@pure Base.Tuple(::Powers{pows}) where {pows} = pows
@pure Base.getindex(P::Powers, i::Int) = Tuple(P)[i]

@pure Powers(x) = Powers{()}()
@pure Powers(x::Type{<: AbstractNode{T, N, pow}}) where {T, N, pow} = Powers{(pow, Tuple(Powers(T))...)}()
Powers(x::AbstractNode) = Powers(typeof(x))

@pure Base.sum(::Powers{p}) where {p} = sum(p)
@pure Base.sum(::Powers{()}) = 0

@pure Base.tail(::Powers{p}) where {p} = Powers(Base.tail(p))
