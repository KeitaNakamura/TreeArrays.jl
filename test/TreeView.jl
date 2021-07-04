@testset "TreeView" begin
    for node in (Node{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2, 1}(),
                 HashNode{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2, 1}(),
                 DynamicNode{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2}(2,2),
                 DynamicHashNode{Node{LeafNode{Float64, 2, 1}, 2, 1}, 2}(2,2))
        A = TreeView(node)

        @test size(A) == (8, 8)

        A[1:3, 1:3] .= reshape(1:9, 3, 3)
        @test A[1:3, 1:3] == reshape(1:9, 3, 3)

        A[7:8, 7:8] .= reshape(11:14, 2, 2)
        @test A[7:8, 7:8] == reshape(11:14, 2, 2)

        # check activation
        mask = map(eachindex(A)) do i
            isactive(A, Tuple(i)...)
        end
        @test all(mask[1:3, 1:3])
        @test all(mask[7:8, 7:8])
        @test !any(mask[1:3, 4:6])
        @test !any(mask[7:8, 1:3])

        # nleaves
        @test nleaves(A) == 3*3 + 2*2

        # deactivating
        for i in CartesianIndices((1:2, 1:2))
            A[i] = nothing
            @test isactive(A, Tuple(i)...) == false
        end

        # cleanup!
        TreeArrays.cleanup!(A.rootnode)
        @test isallocated(A.rootnode, 1) == true
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 1), 1) == false

        # check allocation after deactivating
        A .= nothing
        @test isallocated(A.rootnode, 1) == true
        @test isallocated(A.rootnode, 2) == false
        @test isallocated(A.rootnode, 3) == false
        @test isallocated(A.rootnode, 4) == true
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 1), 1) == false
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 1), 2) == true
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 1), 3) == true
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 1), 4) == true
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 4), 1) == false
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 4), 2) == false
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 4), 3) == false
        @test isallocated(TreeArrays.unsafe_getindex(A.rootnode, 4), 4) == true

        # cleanup!
        TreeArrays.cleanup!(A.rootnode)
        @test isallocated(A.rootnode, 1) == false
        @test isallocated(A.rootnode, 2) == false
        @test isallocated(A.rootnode, 3) == false
        @test isallocated(A.rootnode, 4) == false
    end
    @testset "threads computations" begin
        for node in (Node{Node{LeafNode{Float64, 2, 3}, 2, 3}, 2, 3}(),
                     HashNode{Node{LeafNode{Float64, 2, 3}, 2, 3}, 2, 3}(),
                     DynamicNode{Node{LeafNode{Float64, 2, 3}, 2, 3}, 2}(8,8))
            n = 2^3 * 2^3 * 2^3
            A = TreeView(node)
            @test size(A) == (n, n)

            A[1:100, 1:100] .= 1
            A[200:end, 400:end] .= 1
            A[400:end, 500:end] .= nothing
            @test nleaves(A) == 100*100 + length(200:n)*length(400:n) - length(400:n)*length(500:n)

            A .= nothing
            @test nleaves(A) == 0
        end
    end
end
