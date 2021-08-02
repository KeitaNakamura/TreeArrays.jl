@testset "ContinuousView" begin
    for node in (Node{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2, 3}(),
                 HashNode{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2, 3}(),
                 DynamicNode{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2}(8,8),
                 DynamicHashNode{Node{LeafNode{Float64, 2, 2}, 2, 3}, 2}(8,8))
        A = TreeView(node)

        v = continuousview(A, 11:30, 41:70)
        v .= OffsetArray(reshape(1:600, 20, 30), 11:30, 41:70)
        @test size(v) == (20, 30)
        @test A[11:30, 41:70] == reshape(1:600, 20, 30)

        v = spotview(A, 11, 41)
        @test size(v) == (5, 5)
        @test v == OffsetArray(reshape(1:600, 20, 30)[1:5, 1:5], 11:15, 41:45)
    end
end
