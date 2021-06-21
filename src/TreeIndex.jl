struct TreeIndex{N}
    I::NTuple{N, Int}
end

@generated function checktreebounds(x::AbstractNode{<: Any, L}, index::TreeIndex{N}) where {L, N}
    if length(Tuple(TreeSize(x))) != N
        return :(error("invalid TreeIndex"))
    end
    code = :(checkmask(x, index.I[1]))
    if N > 1
        code = quote
            $code
            checktreebounds()
        end
    end
    quote
        checktreebounds()
    end
end


struct TreeSize{dims}
    function TreeSize{dims}() where {dims}
        new{dims::Tuple{Vararg{Int}}}()
    end
end
Base.Tuple(::TreeSize{dims}) where {dims} = dims

@pure TreeSize(::Nothing) = TreeSize{()}()
@pure TreeSize(x::Type{<: AbstractNode}) = TreeSize{(length(x), Tuple(TreeSize(childtype(x)))...)}()
TreeSize(x::AbstractNode) = TreeSize(typeof(x))
