@inline nfill(v, n::Val) = ntuple(i -> v, n)
