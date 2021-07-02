@testset "LeafNode" begin
    node = @inferred LeafNode{Float64, 2, 2}()
    @test TreeArrays.childtype(node) === nothing
    @test TreeArrays.leaftype(node) == LeafNode{Float64, 2, 2}
    @test TreeArrays.leafeltype(node) == Float64
    @test size(node) === (4, 4)

    # getindex/setindex!
    node[1] = 2
    node[3] = 4
    @test node[1] == 2
    @test node[3] == 4

    # deactivate!
    TreeArrays.deactivate!(node)
    @test TreeArrays.anyactive(node) == false
    @test TreeArrays.unsafe_getindex(node, 1) == 2
    @test TreeArrays.unsafe_getindex(node, 3) == 4
end
