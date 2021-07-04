@testset "eachleaf!" begin
    # test with/without threads
    for node in (Node{Node{LeafNode{Float64, 2, 3}, 2, 3}, 2, 3}(),
                 Node{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2, 1}(),
                 HashNode{Node{LeafNode{Float64, 2, 3}, 2, 3}, 2, 3}(),
                 HashNode{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2, 1}(),
                 DynamicNode{Node{LeafNode{Float64, 2, 3}, 2, 3}, 2}(8,8),
                 DynamicNode{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2}(2,2),
                 DynamicHashNode{Node{LeafNode{Float64, 2, 3}, 2, 3}, 2}(8,8),
                 DynamicHashNode{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2}(2,2),)
        A = TreeView(node)
        A .= 1

        # eachleaf! for all
        eachleaf!(x -> 3x, A)
        @test all(==(3), A)

        # eachleaf! for part matrix
        eachleaf!(x -> 2x, A, :, 1:3)
        @test all(==(6), A[:, 1:3])
        @test all(==(3), A[:, 4:end])
    end
end
