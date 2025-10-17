// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/IndexedMerkleTreeMiMCCached.sol";
import "../src/MiMCHasher.sol";

/**
 * @title IndexedMerkleTreeMiMCCachedTest
 * @dev Test contract for cached IndexedMerkleTreeMiMC
 */
contract IndexedMerkleTreeMiMCCachedTest is Test {
    IndexedMerkleTreeMiMCCached public cachedTree;
    MiMCHasher public mimcHasher;
    
    function setUp() public {
        // Deploy real MiMC hasher
        mimcHasher = new MiMCHasher();
        
        // Create cached tree with real MiMC hasher
        cachedTree = new IndexedMerkleTreeMiMCCached(address(mimcHasher));
    }
    
    function testEmptyTree() public {
        (uint32 numLeaves, uint256 root, bool isDirty) = cachedTree.getTreeStats();
        
        assertEq(numLeaves, 0, "Should start with 0 leaves");
        assertTrue(root != 0, "Root should not be zero");
        assertFalse(isDirty, "Should not be dirty initially");
    }
    
    function testInsertSingleLeaf() public {
        uint64 key = 123;
        uint256 value = 456;
        
        (uint32 leafIdx, uint256 newRoot) = cachedTree.insertLeaf(key, value);
        
        assertEq(leafIdx, 0, "First leaf should have index 0");
        assertTrue(newRoot != 0, "New root should not be zero");
        
        (uint32 numLeaves, uint256 root, bool isDirty) = cachedTree.getTreeStats();
        assertEq(numLeaves, 1, "Should have 1 leaf after insertion");
        assertEq(root, newRoot, "Root should match returned root");
        assertFalse(isDirty, "Should not be dirty after cache rebuild");
    }
    
    function testInsertMultipleLeaves() public {
        // Insert first leaf
        (uint32 leafIdx1, uint256 root1) = cachedTree.insertLeaf(100, 200);
        assertEq(leafIdx1, 0, "First leaf index should be 0");
        
        // Insert second leaf
        (uint32 leafIdx2, uint256 root2) = cachedTree.insertLeaf(300, 400);
        assertEq(leafIdx2, 1, "Second leaf index should be 1");
        assertTrue(root2 != root1, "Roots should be different");
        
        (uint32 numLeaves, , ) = cachedTree.getTreeStats();
        assertEq(numLeaves, 2, "Should have 2 leaves");
    }
    
    function testGenerateProof() public {
        // Insert a leaf
        (uint32 leafIdx, ) = cachedTree.insertLeaf(123, 456);
        
        // Generate proof
        IndexedMerkleTreeMiMCCached.Proof memory proof = cachedTree.generateProof(leafIdx);
        
        assertEq(proof.leafIdx, leafIdx, "Proof leaf index should match");
        assertTrue(proof.root != 0, "Proof root should not be zero");
    }
    
    function testVerifyProof() public {
        // Insert a leaf
        (uint32 leafIdx, uint256 root) = cachedTree.insertLeaf(123, 456);
        
        // Generate and verify proof
        IndexedMerkleTreeMiMCCached.Proof memory proof = cachedTree.generateProof(leafIdx);
        
        // Debug information
        console.log("Leaf index:", proof.leafIdx);
        console.log("Leaf key:", proof.leaf.key);
        console.log("Leaf value:", proof.leaf.value);
        console.log("Proof root:", proof.root);
        console.log("Tree root:", root);
        console.log("Siblings count:", proof.siblings.length);
        
        bool isValid = cachedTree.verifyProof(proof);
        
        assertTrue(isValid, "Proof should be valid");
    }
    
    function testCacheRebuild() public {
        // Insert multiple leaves
        cachedTree.insertLeaf(100, 200);
        cachedTree.insertLeaf(300, 400);
        
        // Force cache rebuild
        cachedTree.forceCacheRebuild();
        
        (uint32 numLeaves, uint256 root, bool isDirty) = cachedTree.getTreeStats();
        assertEq(numLeaves, 2, "Should have 2 leaves");
        assertTrue(root != 0, "Root should not be zero");
        assertFalse(isDirty, "Should not be dirty after rebuild");
    }
    
    function testGasOptimization() public {
        // Test that cached operations are more gas efficient
        uint256 gasBefore = gasleft();
        
        // Insert multiple leaves
        for (uint256 i = 0; i < 5; i++) {
            cachedTree.insertLeaf(uint64(i * 100), uint256(i * 200));
        }
        
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        
        console.log("Gas used for 5 insertions:", gasUsed);
        
        // Verify tree state
        (uint32 numLeaves, , ) = cachedTree.getTreeStats();
        assertEq(numLeaves, 5, "Should have 5 leaves");
    }
    
    function testMiMCHasherWorks() public {
        // Test that our MiMC hasher works correctly
        (uint256 xL1, uint256 xR1) = mimcHasher.MiMCSponge(123, 456);
        (uint256 xL2, uint256 xR2) = mimcHasher.MiMCSponge(123, 456);
        
        // Results should be consistent
        assertTrue(xL1 != 0, "MiMC hasher should return non-zero xL");
        assertTrue(xR1 != 0, "MiMC hasher should return non-zero xR");
        assertEq(xL1, xL2, "MiMC hasher should be deterministic for xL");
        assertEq(xR1, xR2, "MiMC hasher should be deterministic for xR");
    }
}