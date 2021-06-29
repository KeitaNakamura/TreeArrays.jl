struct ShowArray{T, N, A <: AbstractArray{T, N}} <: AbstractArray{Union{Int, T}, N}
    array::A
end
Base.size(x::ShowArray) = size(x.array)
isstored(x::ShowArray, i::Int...) = (@_propagate_inbounds_meta; isassigned(x.array, i...))
Base.getindex(x::ShowArray, i::Int...) = (@_propagate_inbounds_meta; isstored(x, i...) ? x.array[i...] : 0)

Base.replace_in_print_matrix(A::SubArray{<: Any, <: Any, <: ShowArray}, i::Integer, j::Integer, s::AbstractString) =
    isstored(parent(A), Base.reindex(A.indices, (i, j))...) ? s : Base.replace_with_centered_mark(s)
Base.replace_in_print_matrix(A::ShowArray, i::Integer, j::Integer, s::AbstractString) =
    isstored(A, i, j) ? s : Base.replace_with_centered_mark(s)

Base.show(io::IO, mime::MIME"text/plain", x::Union{AbstractNode, TreeView, ContinuousView}) = show(io, mime, ShowArray(x))
Base.show(io::IO, x::Union{AbstractNode, TreeView, ContinuousView}) = show(io, ShowArray(x))

function Base.show(io::IO, ::MIME"text/plain", x::ShowArray)
    print(io, summary(x.array), ":")
    show(IOContext(io), x)
end
Base.show(io::IO, x::ShowArray) = Base.show(convert(IOContext, io), x)
function Base.show(io::IOContext, x::ShowArray)
    ioc = IOContext(io, :compact => true)
    println(ioc)
    Base.print_matrix(ioc, x)
    nothing
end
