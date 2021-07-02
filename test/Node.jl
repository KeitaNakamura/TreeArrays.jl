@testset "Node" begin
    for NodeType in (Node{LeafNode{Float64, 2, 2}, 2, 2},
                     HashNode{LeafNode{Float64, 2, 2}, 2, 2})
        node = NodeType()
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
        @test TreeArrays.isactive(node, 1) == false
        @test !TreeArrays.isnull(TreeArrays.unsafe_getindex(node, 1)) # still not yet null

        # allocate!
        TreeArrays.allocate!(node, 1)
        @test TreeArrays.isactive(node, 1)
        @test TreeArrays.unsafe_getindex(node[1], 1) == 3
        @test !TreeArrays.anyactive(node[1])
        node[1][1] = 3
        @test TreeArrays.isactive(node[1], 1)
        #
        @test node[1][1] == 3
        TreeArrays.allocate!(node, 3)
        @test TreeArrays.isactive(node, 3)

        # nleaves
        node[3][1] = 10
        @test TreeArrays.isactive(node[3], 1)
        @test nleaves(node) == 2

        # deactivate!
        TreeArrays.deactivate!(node)
        @test !TreeArrays.anyactive(node)
        @test !TreeArrays.anyactive(TreeArrays.unsafe_getindex(node, 1))
        @test !TreeArrays.anyactive(TreeArrays.unsafe_getindex(node, 3))
        if node isa Node
            @test TreeArrays.unsafe_getindex(node, 2) === childnull
            @test TreeArrays.unsafe_getindex(node, 4) === childnull
            @test_throws Exception TreeArrays.unsafe_getindex(node, 2).data
            @test_throws Exception TreeArrays.unsafe_getindex(node, 4).data
        else
            @test !haskey(node.data, 2)
            @test !haskey(node.data, 4)
        end

        # cleanup!
        TreeArrays.cleanup!(node)
        for i in eachindex(node)
            @test node[i] === childnull
        end
    end
end
