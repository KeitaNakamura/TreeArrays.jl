mutable struct MyType
    a::Int
    b::Float64
end

@testset "TreeArray" begin
    for NodeType in (Node{Node{LeafNode{Float64, 2, 2}, 2, 2}, 2, 2},
                     HashNode{Node{LeafNode{Float64, 2, 2}, 2, 2}, 2, 2},
                     DynamicNode{Node{LeafNode{Float64, 2, 2}, 2, 2}, 2},
                     DynamicHashNode{Node{LeafNode{Float64, 2, 2}, 2, 2}, 2})
        A = @inferred TreeArray(NodeType, 16, 16)

        @test size(A) == (16, 16)
        if NodeType <: Union{Node, HashNode}
            @test size(A.tree.rootnode) == (4, 4)
        else
            @test size(A.tree.rootnode) == (1, 1)
        end

        A[1:3, 1:3] .= reshape(1:9, 3, 3)
        @test A[1:3, 1:3] == reshape(1:9, 3, 3)

        A[11:13, 11:13] .= reshape(11:19, 3, 3)
        @test A[11:13, 11:13] == reshape(11:19, 3, 3)

        # check activation
        mask = map(eachindex(A)) do i
            isactive(A, Tuple(i)...)
        end
        @test all(mask[1:3, 1:3])
        @test all(mask[11:13, 11:13])
        @test !any(mask[1:3, 4:10])
        @test !any(mask[11:13, 1:3])

        # allocate!
        A.tree .= nothing
        mask = similar(A, Bool)
        TreeArrays.allocate!(A, mask)
        @test map(i -> isactive(A, i), eachindex(A)) == mask
    end
    for NodeType in (Node{Node{LeafNode{MyType, 2, 2}, 2, 2}, 2, 2},
                     HashNode{Node{LeafNode{MyType, 2, 2}, 2, 2}, 2, 2},
                     DynamicNode{Node{LeafNode{MyType, 2, 2}, 2, 2}, 2},
                     DynamicHashNode{Node{LeafNode{MyType, 2, 2}, 2, 2}, 2})
        A = @inferred TreeArray(NodeType, 16, 16)

        # allocate!
        mask = similar(A, Bool)
        TreeArrays.allocate!(A, mask)
        @test map(i -> isactive(A, i), eachindex(A)) == mask

        # isallocated
        @test map(i -> TreeArrays.isallocated(A, i), eachindex(A)) == mask
        A .= nothing
        @test map(i -> TreeArrays.isallocated(A, i), eachindex(A)) == mask
        TreeArrays.cleanup!(A)
        @test map(i -> TreeArrays.isallocated(A, i), eachindex(A)) == falses(16, 16)

        for i in 1:length(A)
            A.a[i] = i
        end
        @test A.a == reshape(1:16*16, 16, 16)
        @test A.b == zeros(16, 16)
    end
end
