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

        for i in 1:length(A)
            A[i] = i
        end
        v = blockview(A, 2, 3)
        @test size(v) == (4, 4)
        @test v == OffsetArray(reshape(1:length(A), size(A))[5:8, 9:12], 5:8, 9:12)

        v = blockaroundview(A, 2, 1)
        @test size(v) == (8, 6)
        @test v == OffsetArray(reshape(1:length(A), size(A))[3:10, 1:6], 3:10, 1:6)

        v = blockaroundview(A, 4, 4)
        @test size(v) == (8, 8)
        @test v == OffsetArray(reshape(1:length(A), size(A))[11:18, 11:18], 11:18, 11:18)

        v = blockaroundview(A, 64, 63)
        @test size(v) == (6, 8)
        @test v == OffsetArray(reshape(1:length(A), size(A))[251:256, 247:254], 251:256, 247:254)
    end
end
