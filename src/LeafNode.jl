abstract type AbstractLeafNode{T, N, p} <: AbstractNode{T, N, p} end

Base.size(x::AbstractLeafNode) = size(typeof(x))
Base.IndexStyle(::Type{<: AbstractLeafNode}) = IndexLinear()

@inline function Base.getindex(x::AbstractLeafNode, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i]
end

@inline function Base.setindex!(x::AbstractLeafNode, v, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.data[i] = v
    x
end

@generated function construct(::Type{T}) where {T}
    exps = [:(zero($T)) for T in fieldtypes(T)]
    quote
        @_inline_meta
        T($(exps...))
    end
end
@generated function allocate!(x::AbstractLeafNode{T}, i::Int) where {T}
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
            Allocated(x, i)
        end
    else
        quote
            @boundscheck checkbounds(x, i)
            @inbounds getmask(x)[i] = true
            Allocated(x, i)
        end
    end
end

function allocate!(x::AbstractLeafNode, mask::AbstractArray{Bool})
    checkbounds(x, CartesianIndices(mask))
    @simd for i in eachindex(mask)
        @inbounds mask[i] && allocate!(x, i)
    end
end

@inline function deactivate!(x::AbstractLeafNode)
    isnull(x) || fill!(getmask(x), false)
    x
end

isallocated(x::AbstractLeafNode, i::Int) = isassigned(x.data, i)
cleanup!(x::AbstractLeafNode) = x
nleaves(x::AbstractLeafNode) = count(getmask(x))


struct LeafNode{T, N, p} <: AbstractLeafNode{T, N, p}
    data::MaskedDenseArray{T, N}
    LeafNode{T, N, p}(data) where {T, N, p} = new(data)
    LeafNode{T, N, p}(::UndefInitializer) where {T, N, p} = new()
end

function LeafNode{T, N, p}() where {T, N, p}
    dims = size(LeafNode{T, N, p})
    data = MaskedDenseArray{T}(undef, dims)
    LeafNode{T, N, p}(data)
end


struct StructLeafNode{T, N, p, Ttuple} <: AbstractLeafNode{T, N, p}
    data::MaskedStructArray{T, N, Ttuple}
    StructLeafNode{T, N, p, Ttuple}(data) where {T, N, p, Ttuple} = new(data)
    StructLeafNode{T, N, p, Ttuple}(::UndefInitializer) where {T, N, p, Ttuple} = new()
end

function StructLeafNode{T, N, p, Ttuple}() where {T, N, p, Ttuple}
    dims = size(StructLeafNode{T, N, p})
    data = MaskedStructArray{T}(undef, dims)
    StructLeafNode{T, N, p, Ttuple}(data)
end

Base.propertynames(x::StructLeafNode) = (:data, propertynames(x.data)...)
@inline function Base.getproperty(x::StructLeafNode{T, N, p}, name::Symbol) where {T, N, p}
    name == :data && return getfield(x, :data)
    LeafNode{fieldtype(T, name), N, p}(getproperty(getfield(x, :data), name))
end

macro StructLeafNode(ex)
    @assert Meta.isexpr(ex, :braces)
    @assert length(ex.args) == 3
    T, N, p = ex.args
    esc(quote
        Ttuple = $StructArrays.map_params(t -> Array{t, $N}, $StructArrays.staticschema($T))
        StructLeafNode{$T, $N, $p, Ttuple}
    end)
end
