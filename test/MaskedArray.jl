@testset "MaskedDenseArray/MaskedHashArray" begin
    for T in (Float32, Float64)
        for ArrayType in (TreeArrays.MaskedDenseArray, TreeArrays.MaskedHashArray)
            x = (@inferred ArrayType{T}(undef, 2, 3))::ArrayType{T, 2}
            @test size(x) == (2, 3)
            @test size(x.mask) == (2, 3)
            @test any(x.mask) == false

            # getindex, checkactive
            @test_throws Exception x[i]

            # setindex
            x[1] = 2
            @test TreeArrays.isactive(x, 1) == true
            @test x[1] == 2

            # setindex nothing
            x[1] = nothing
            @test TreeArrays.isactive(x, 1) == false
            if x isa TreeArrays.MaskedDenseArray
                @test x.data[1] == 2 # still value is not changed
            else
                @test x.data[TreeArrays.FastHashInt(1)] == 2 # still value is not changed
            end
        end
    end
end
