@testset "ContinuousView" begin
    for node in (Node{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2, 3}(),
                 HashNode{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2, 3}(),
                 DynamicNode{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2}(8,8),
                 DynamicHashNode{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2}(8,8))
        A = TreeView(node)

        v = ContinuousView(A, 11:30, 41:70)
        v .= reshape(1:600, 20, 30)
        @test size(v) == (20, 30)
        @test A[11:30, 41:70] == reshape(1:600, 20, 30)

        v = SpotView(A, 11, 41)
        @test size(v) == (4, 4)
        @test v == reshape(1:600, 20, 30)[1:4, 1:4]
    end
end
