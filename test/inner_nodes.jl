@testset "Node/HashNode/DynamicNode/DynamicHashNode" begin
    for node in (Node{LeafNode{Float64, 2, 2}, 2, 2}(),
                 HashNode{LeafNode{Float64, 2, 2}, 2, 2}(),
                 DynamicNode{LeafNode{Float64, 2, 2}, 2}(4, 4),
                 DynamicHashNode{LeafNode{Float64, 2, 2}, 2}(4, 4))
        @test TreeArrays.childtype(node) == LeafNode{Float64, 2, 2}
        @test TreeArrays.leaftype(node) == LeafNode{Float64, 2, 2}
        @test TreeArrays.leafeltype(node) == Float64
        @test @inferred(size(node)) == (4, 4)

        @test node[1] === TreeArrays.null(TreeArrays.childtype(node))
        childnull = TreeArrays.null(TreeArrays.childtype(node))

        # cannot set null
        @test_throws Exception node[1] = childnull

        # setindex!
        node[1] = LeafNode{Float64, 2, 2}()
        @test TreeArrays.isactive(node, 1) == true
        node[1][1] = 3
        @test TreeArrays.isactive(node[1], 1) == true

        # setindex! nothing
        node[1] = nothing
        @test isactive(node, 1) == false
        @test isallocated(node, 1) == true

        # allocate!
        TreeArrays.allocate!(node, 1)
        @test isactive(node, 1) == true
        @test isallocated(node, 1) == true
        @test !any(TreeArrays.getmask(node[1]))           # child is still deactivated
        @test TreeArrays.unsafe_getindex(node[1], 1) == 3 # but the value is not changed
        node[1][1] = 3
        @test TreeArrays.isactive(node[1], 1)
        @test node[1][1] == 3
        #
        TreeArrays.allocate!(node, 3)
        @test isactive(node, 3) == true
        @test isallocated(node, 3) == true

        # nleaves
        node[3][1] = 10
        @test TreeArrays.isactive(node[3], 1)
        @test nleaves(node) == 2

        # deactivate!
        TreeArrays.deactivate!(node)
        @test !any(TreeArrays.getmask(node))
        # children are also deactivated
        @test !any(TreeArrays.getmask(TreeArrays.unsafe_getindex(node, 1)))
        @test !any(TreeArrays.getmask(TreeArrays.unsafe_getindex(node, 3)))
        # but still allocated
        @test isallocated(node, 1) == true
        @test isallocated(node, 3) == true
        # other children are not allocated
        @test isallocated(node, 2) == false
        @test isallocated(node, 4) == false

        # cleanup!
        TreeArrays.cleanup!(node)
        for i in eachindex(node)
            @test node[i] === childnull
        end
    end
end
