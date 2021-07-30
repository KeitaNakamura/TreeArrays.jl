const CustomShowArrays = Union{MaskedArray, PropertyArray, AbstractNode, TreeView, AbstractTreeArray, ContinuousView}

struct CDot end
Base.show(io::IO, x::CDot) = print(io, "⋅")

struct ShowWrapper{T, N, A <: AbstractArray{T, N}} <: AbstractArray{T, N}
    parent::A
end
Base.size(x::ShowWrapper) = size(x.parent)
Base.axes(x::ShowWrapper) = axes(x.parent)
@inline function Base.getindex(x::ShowWrapper, i::Int...)
    @_propagate_inbounds_meta
    p = x.parent
    isactive(p, i...) ? maybewrap(p[i...]) : CDot()
end
maybewrap(x) = x
maybewrap(x::CustomShowArrays) = ShowWrapper(x)

Base.summary(io::IO, x::ShowWrapper) = summary(io, x.parent)
Base.show(io::IO, mime::MIME"text/plain", x::CustomShowArrays) = show(io, mime, ShowWrapper(x))
