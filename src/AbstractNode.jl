abstract type AbstractNode{T, N, pow} <: AbstractArray{T, N} end

@pure Base.length(::Type{T}) where {T <: AbstractNode} = prod(size(T))
@pure Base.size(::Type{<: AbstractNode{T, N, pow}}) where {T, N, pow} = nfill(1 << pow, Val(N))
@pure getpower(::Type{<: AbstractNode{T, N, pow}}) where {T, N, pow} = pow

Base.length(x::AbstractNode) = length(typeof(x))
Base.size(x::AbstractNode) = size(typeof(x))

childtype(x::AbstractNode) = childtype(typeof(x))
leaftype(x::AbstractNode) = leaftype(typeof(x))
leafeltype(x::AbstractNode) = leafeltype(typeof(x))

isactive(x::AbstractNode, i...) = (@_propagate_inbounds_meta; isactive(x.data, i...))
allactive(x::AbstractNode) = allactive(x.data)
anyactive(x::AbstractNode) = anyactive(x.data)

get_prev(x::AbstractNode) = x.prev[]
set_prev!(x::AbstractNode, v) = (x.prev[] = v; x)
get_next(x::AbstractNode) = x.next[]
set_next!(x::AbstractNode, v) = (x.next[] = v; x)

@inline function Base.getindex(x::AbstractNode, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds x[sub2ind(x, i...)]
end

@inline function Base.setindex!(x::AbstractNode, v, i::Int...)
    @boundscheck checkbounds(x, i...)
    @inbounds x[sub2ind(x, i...)] = v
end

const Pointer{T <: AbstractNode} = Base.RefValue{Union{T, Nothing}}


struct Powers{pows}
    function Powers{pows}() where {pows}
        new{pows::Tuple{Vararg{Int}}}()
    end
end
@pure Powers(p::Tuple{Vararg{Int}}) = Powers{p}()
@pure Powers(p::Int...) = Powers{p}()

@pure Base.Tuple(::Powers{pows}) where {pows} = pows
@pure Base.getindex(P::Powers, i::Int) = Tuple(P)[i]

@pure Powers(::Nothing) = Powers{()}()
@pure Powers(::Type{Tnode}) where {pow, Tnode <: AbstractNode{<: Any, <: Any, pow}} = Powers{(pow, Tuple(Powers(childtype(Tnode)))...)}()
Powers(x::AbstractNode) = Powers(typeof(x))

@pure Base.sum(::Powers{p}) where {p} = sum(p)
@pure Base.sum(::Powers{()}) = 0

@pure Base.tail(::Powers{p}) where {p} = Powers(Base.tail(p))

@pure treeheight(::Powers{p}) where {p} = length(p)
@pure leafpower(::Powers{p}) where {p} = p[end]


# divrem(ind, 1 << p)
_divrem_pow(ind::Int, p::Int) = (d = ind >> p; (d, ind - (d << p)))

@inline ind2sub(node::AbstractNode{<: Any, N, p}, ind::Int) where {N, p} = _ind2sub_recurse(Val(N), p, ind-1)
@inline _ind2sub_recurse(::Val{1}, p::Int, ind::Int) = ind + 1
@inline function _ind2sub_recurse(::Val{N}, p::Int, ind::Int) where {N}
    indnext, r = _divrem_pow(ind, p)
    (r + 1, _ind2sub_recurse(Val(N-1), p, indnext)...)
end

@inline sub2ind(node::AbstractNode{<: Any, N, p}, inds::Int...) where {N, p} = _sub2ind_recurse(Val(1), p, inds[1], Base.tail(inds)...)
@inline _sub2ind_recurse(::Val, p, ind) = ind
@inline function _sub2ind_recurse(::Val{N}, p, ind, i::Integer, I::Integer...) where {N}
    _sub2ind_recurse(Val(N+1), p, ind+((i-1)*N)<<p, I...)
end
