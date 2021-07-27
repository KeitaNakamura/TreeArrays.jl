struct LeafNode{T, N, p} <: AbstractNode{T, N, p}
    data::MaskedDenseArray{T, N}
    LeafNode{T, N, p}(data) where {T, N, p} = new(data)
    LeafNode{T, N, p}(::UndefInitializer) where {T, N, p} = new()
end

function LeafNode{T, N, p}() where {T, N, p}
    dims = size(LeafNode{T, N, p})
    data = MaskedDenseArray{T}(undef, dims)
    LeafNode{T, N, p}(data)
end

Base.size(x::LeafNode) = size(typeof(x))
Base.IndexStyle(::Type{<: LeafNode}) = IndexLinear()

@inline function Base.getindex(x::LeafNode, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i]
end

@inline function Base.setindex!(x::LeafNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i] = v
    x
end

@inline function deactivate!(x::LeafNode)
    isnull(x) || fill!(getmask(x), false)
    x
end

@generated function construct(::Type{T}) where {T}
    exps = [:(zero($T)) for T in fieldtypes(T)]
    quote
        @_inline_meta
        T($(exps...))
    end
end
@generated function allocate!(x::LeafNode{T}, i::Int) where {T}
    if T.mutable
        quote
            @boundscheck checkbounds(x, i)
            @inbounds begin
                isactive(x, i) && return x[i]
                if isassigned(x.data, i)
                    leaf = unsafe_getindex(x.data, i)
                else
                    leaf = construct(T)
                end
                x[i] = leaf
            end
            leaf
        end
    else
        quote
            @boundscheck checkbounds(x, i)
            @inbounds begin
                if isactive(x, i)
                    x[i]
                else
                    getmask(x)[i] = true
                    unsafe_getindex(x, i)
                end
            end
        end
    end
end

function allocate!(x::LeafNode, mask::AbstractArray{Bool})
    checkbounds(x, CartesianIndices(mask))
    @simd for i in eachindex(mask)
        @inbounds mask[i] && allocate!(x, i)
    end
end

cleanup!(x::LeafNode) = x

nleaves(x::LeafNode) = count(getmask(x))
