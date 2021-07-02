@testset "utils" begin
    @test @inferred(TreeArrays.nfill(2, Val(2))) === (2,2)
    @test @inferred(TreeArrays.nfill(2, Val(3))) === (2,2,2)
end

@testset "Power2" begin
    @test @inferred(TreeArrays.Power2(0)) == 2^0
    @test @inferred(TreeArrays.Power2(1)) == 2^1
    @test @inferred(TreeArrays.Power2(2)) == 2^2

    x = TreeArrays.Power2(3)
    x′ = 2^3
    @test @inferred(2 * x) === 2 * x′
    @test @inferred(x * 2) === x′ * 2
    @test @inferred(x * x) === TreeArrays.Power2(6) == x′ * x′

    @test @inferred(x + 1) === x′ + 1
    @test @inferred(x - 1) === x′ - 1
    @test @inferred(1 + x) === 1 + x′
    @test @inferred(1 - x) === 1 - x′

    @test @inferred(div(20, x)) === div(20, x′)
    @test @inferred(rem(20, x)) === rem(20, x′)
    @test @inferred(divrem(20, x)) === divrem(20, x′)

    @test @inferred(zero(x)) === TreeArrays.Power2(0)
end
