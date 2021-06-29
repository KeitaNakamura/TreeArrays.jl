abstract type AbstractNode{T, N, pow} <: AbstractArray{T, N} end

@pure Base.length(::Type{T}) where {T <: AbstractNode} = prod(size(T))
@pure Base.size(::Type{<: AbstractNode{T, N, pow}}) where {T, N, pow} = nfill(1 << pow, Val(N))

Base.length(x::AbstractNode) = length(typeof(x))
Base.size(x::AbstractNode) = size(typeof(x))

@pure null(::Type{Tnode}) where {T, N, pow, Tnode <: AbstractNode{T, N, pow}} = Tnode(nothing)
null(x::AbstractNode) = null(typeof(x))
isnull(x::AbstractNode) = x === null(x)

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


struct Powers{pows}
    function Powers{pows}() where {pows}
        new{pows::Tuple{Vararg{Int}}}()
    end
end
@pure Powers(p::Tuple{Vararg{Int}}) = Powers{p}()
@pure Powers(p::Int...) = Powers{p}()

@pure Base.Tuple(::Powers{p}) where {p} = p
@pure Base.getindex(::Powers{p}, i::Int) where {p} = p[i]
@pure Base.length(::Powers{p}) where {p} = length(p)
@pure Base.lastindex(P::Powers) = length(P)
@pure Base.firstindex(P::Powers) = 1

@pure Powers(::Nothing) = Powers{()}()
@pure Powers(::Type{Tnode}) where {pow, Tnode <: AbstractNode{<: Any, <: Any, pow}} = Powers{(pow, Tuple(Powers(childtype(Tnode)))...)}()
Powers(x::AbstractNode) = Powers(typeof(x))

@pure Base.sum(::Powers{p}) where {p} = sum(p)
@pure Base.sum(::Powers{()}) = 0

@pure Base.tail(::Powers{p}) where {p} = Powers(Base.tail(p))


# divrem(ind, 1 << p)
@inline _divrem_pow(ind::Int, p::Int) = (d = ind >> p; (d, ind - (d << p)))

@inline ind2sub(node::AbstractNode{<: Any, N, p}, ind::Integer) where {N, p} = _ind2sub_recurse(Val(N), p, ind-one(ind))
@inline _ind2sub_recurse(::Val{1}, p::Int, ind::Int) = ind + 1
@inline function _ind2sub_recurse(::Val{N}, p::Int, ind::Int) where {N}
    indnext, r = _divrem_pow(ind, p)
    (r+one(r), _ind2sub_recurse(Val(N-1), p, indnext)...)
end

@inline sub2ind(p::Int, inds::Integer...) = _sub2ind_recurse(Val(1), p, inds...)
@inline sub2ind(P::Powers, inds::Integer...) = sub2ind(P[1], inds...)
@inline sub2ind(node::AbstractNode, inds::Integer...) = sub2ind(Powers(node), inds...)
@inline _sub2ind_recurse(::Val, p, ind) = ind
@inline function _sub2ind_recurse(::Val{N}, p, ind, i::Integer, I::Integer...) where {N}
    _sub2ind_recurse(Val(N+1), p, ind+((i-one(i))*N)<<p, I...)
end
