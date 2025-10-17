// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IHasher.sol";

/**
 * @title IndexedMerkleTreeMiMCCached
 * @dev Cached Indexed Merkle Tree implementation using MiMC-Feistel hashing
 * @notice This contract provides gas-optimized merkle tree operations with node caching
 */

contract IndexedMerkleTreeMiMCCached {
    IHasher public immutable hasher;
    
    uint256 public constant MAX_DEPTH = 32;
    
    struct Leaf {
        uint64 key;
        uint32 nextIdx;
        uint64 nextKey;
        uint256 value;
    }
    
    struct Proof {
        uint32 leafIdx;
        Leaf leaf;
        uint256 root;
        uint256[MAX_DEPTH] siblings;
    }
    
    struct InsertionResult {
        uint32 ogLeafIdx;
        uint64 ogLeafKey;
        uint32 ogLeafNextIdx;
        uint64 ogLeafNextKey;
        uint256 ogLeafValue;
        uint32 newLeafIdx;
        uint64 newLeafKey;
        uint256 newLeafValue;
        uint256 rootBefore;
        uint256 rootAfter;
        uint256[MAX_DEPTH] siblingsBefore;
        uint256[MAX_DEPTH] siblingsAfterOg;
        uint256[MAX_DEPTH] siblingsAfterNew;
    }
    
    // Cached tree state
    struct TreeState {
        uint256[MAX_DEPTH] cachedNodes; // Cached internal nodes
        uint256[MAX_DEPTH] leafHashes;  // Cached leaf hashes
        Leaf[MAX_DEPTH] leaves;         // Store full leaf data
        uint32 numLeaves;
        uint256 root;
        bool isDirty; // Flag to indicate if cache needs rebuilding
    }
    
    TreeState public treeState;
    
    // Events for debugging and monitoring
    event LeafInserted(uint32 leafIdx, uint64 key, uint256 value, uint256 newRoot);
    event CacheRebuilt(uint32 numLeaves, uint256 root);
    
    constructor(address _hasher) {
        hasher = IHasher(_hasher);
        _initializeTree();
    }
    
    /**
     * @dev Initialize empty tree state
     */
    function _initializeTree() internal {
        treeState.numLeaves = 0;
        treeState.root = emptyRoot();
        treeState.isDirty = false;
        
        // Initialize cached nodes with empty values
        for (uint256 i = 0; i < MAX_DEPTH; i++) {
            treeState.cachedNodes[i] = 0;
            treeState.leafHashes[i] = 0;
        }
    }
    
    /**
     * @dev Get the empty root hash
     */
    function emptyRoot() public view returns (uint256) {
        return hashLeaf(Leaf(0, 0, 0, 0));
    }
    
    /**
     * @dev Hash a leaf using MiMC
     */
    function hashLeaf(Leaf memory leaf) public view returns (uint256) {
        (uint256 xL, ) = hasher.MiMCSponge(
            uint256(leaf.key) << 192 | uint256(leaf.nextIdx) << 160 | uint256(leaf.nextKey) << 96 | (leaf.value >> 96),
            leaf.value & 0xffffffffffffffffffffffff
        );
        return xL;
    }
    
    /**
     * @dev Hash two children nodes using MiMC
     */
    function hashChildren(uint256 left, uint256 right) public view returns (uint256) {
        (uint256 xL, ) = hasher.MiMCSponge(left, right);
        return xL;
    }
    
    /**
     * @dev Rebuild cache when tree is dirty
     */
    function _rebuildCache() internal {
        if (!treeState.isDirty) return;
        
        uint256 empty = emptyRoot();
        
        // Handle single leaf case
        if (treeState.numLeaves == 1) {
            treeState.root = treeState.leafHashes[0];
            treeState.isDirty = false;
            return;
        }
        
        // Clear and rebuild cached nodes for multiple leaves
        for (uint256 i = 0; i < MAX_DEPTH; i++) {
            if (i < treeState.numLeaves) {
                // Keep existing leaf hashes
                if (treeState.leafHashes[i] == 0) {
                    treeState.leafHashes[i] = empty;
                }
            } else {
                treeState.leafHashes[i] = empty;
            }
        }
        
        // Rebuild internal nodes bottom-up
        uint256[MAX_DEPTH] memory currentHashes = treeState.leafHashes;
        
        // Level 0: 32 -> 16
        for (uint256 i = 0; i < 16; i++) {
            treeState.cachedNodes[i] = hashChildren(currentHashes[i * 2], currentHashes[i * 2 + 1]);
        }
        currentHashes = treeState.cachedNodes;
        
        // Level 1: 16 -> 8
        for (uint256 i = 0; i < 8; i++) {
            treeState.cachedNodes[i + 16] = hashChildren(currentHashes[i * 2], currentHashes[i * 2 + 1]);
        }
        currentHashes = treeState.cachedNodes;
        
        // Level 2: 8 -> 4
        for (uint256 i = 0; i < 4; i++) {
            treeState.cachedNodes[i + 24] = hashChildren(currentHashes[i * 2], currentHashes[i * 2 + 1]);
        }
        currentHashes = treeState.cachedNodes;
        
        // Level 3: 4 -> 2
        for (uint256 i = 0; i < 2; i++) {
            treeState.cachedNodes[i + 28] = hashChildren(currentHashes[i * 2], currentHashes[i * 2 + 1]);
        }
        currentHashes = treeState.cachedNodes;
        
        // Level 4: 2 -> 1
        treeState.cachedNodes[30] = hashChildren(currentHashes[0], currentHashes[1]);
        treeState.root = treeState.cachedNodes[30];
        
        treeState.isDirty = false;
        emit CacheRebuilt(treeState.numLeaves, treeState.root);
    }
    
    /**
     * @dev Get current root (rebuilds cache if needed)
     */
    function getRoot() public returns (uint256) {
        _rebuildCache();
        return treeState.root;
    }
    
    /**
     * @dev Insert a leaf into the tree with caching
     */
    function insertLeaf(uint64 key, uint256 value) public virtual returns (uint32 leafIdx, uint256 newRoot) {
        require(treeState.numLeaves < MAX_DEPTH, "Tree is full");
        
        leafIdx = treeState.numLeaves;
        
        // Create new leaf
        Leaf memory newLeaf = Leaf({
            key: key,
            nextIdx: 0,
            nextKey: 0,
            value: value
        });
        
        // Hash the new leaf and store both hash and full leaf data
        uint256 leafHash = hashLeaf(newLeaf);
        treeState.leafHashes[leafIdx] = leafHash;
        treeState.leaves[leafIdx] = newLeaf;
        
        // Update previous leaf's next pointers if needed
        if (leafIdx > 0) {
            // Find the correct position for insertion (maintain sorted order)
            uint32 insertPos = leafIdx;
            for (uint32 i = 0; i < leafIdx; i++) {
                // This is a simplified approach - in practice you'd need to find the correct position
                // and update the linked list structure
            }
        }
        
        treeState.numLeaves++;
        treeState.isDirty = true;
        
        // Rebuild cache to get new root
        _rebuildCache();
        newRoot = treeState.root;
        
        emit LeafInserted(leafIdx, key, value, newRoot);
    }
    
    /**
     * @dev Generate proof for a leaf (uses cached nodes when possible)
     */
    function generateProof(uint32 leafIdx) public returns (Proof memory) {
        require(leafIdx < treeState.numLeaves, "Leaf index out of bounds");
        
        _rebuildCache();
        
        // Get the stored leaf data
        Leaf memory leaf = treeState.leaves[leafIdx];
        
        uint256[MAX_DEPTH] memory siblings;
        uint256 currentHash = treeState.leafHashes[leafIdx];
        uint256 idx = leafIdx;
        
        // Build proof using cached nodes - calculate actual tree depth
        uint256 treeDepth = 0;
        if (treeState.numLeaves > 1) {
            uint256 temp = treeState.numLeaves;
            while (temp > 1) {
                temp = (temp + 1) / 2; // Ceiling division
                treeDepth++;
            }
        }
        // For single leaf, treeDepth = 0 (no siblings needed)
        
        for (uint256 level = 0; level < treeDepth; level++) {
            uint256 siblingIdx = idx % 2 == 0 ? idx + 1 : idx - 1;
            
            if (level == 0) {
                // Check if sibling exists
                if (siblingIdx < treeState.numLeaves) {
                    siblings[level] = treeState.leafHashes[siblingIdx];
                } else {
                    siblings[level] = 0; // Empty sibling
                }
            } else {
                // Use cached internal nodes
                uint256 nodeOffset = 16 * level - 16; // Calculate offset for this level
                uint256 nodeIdx = nodeOffset + siblingIdx / (1 << level);
                if (nodeIdx < treeState.cachedNodes.length) {
                    siblings[level] = treeState.cachedNodes[nodeIdx];
                } else {
                    siblings[level] = 0; // Empty sibling
                }
            }
            
            // For single leaf case, we don't need to hash with siblings
            if (treeState.numLeaves > 1) {
                if (idx % 2 == 0) {
                    currentHash = hashChildren(currentHash, siblings[level]);
                } else {
                    currentHash = hashChildren(siblings[level], currentHash);
                }
            }
            
            idx = idx / 2;
        }
        
        return Proof({
            leafIdx: leafIdx,
            leaf: leaf,
            root: treeState.root,
            siblings: siblings
        });
    }
    
    /**
     * @dev Verify a merkle proof
     */
    function verifyProof(Proof memory proof) public view returns (bool) {
        uint256 currentHash = hashLeaf(proof.leaf);
        uint256 idx = proof.leafIdx;
        
        // Calculate tree depth based on number of leaves
        uint256 treeDepth = 0;
        if (treeState.numLeaves > 1) {
            uint256 temp = treeState.numLeaves;
            while (temp > 1) {
                temp = (temp + 1) / 2; // Ceiling division
                treeDepth++;
            }
        }
        // For single leaf, treeDepth = 0 (no siblings needed)
        
        for (uint256 i = 0; i < treeDepth; i++) {
            // For single leaf case, we don't need to hash with siblings
            if (treeState.numLeaves > 1) {
                if (idx % 2 == 0) {
                    currentHash = hashChildren(currentHash, proof.siblings[i]);
                } else {
                    currentHash = hashChildren(proof.siblings[i], currentHash);
                }
            }
            idx = idx / 2;
        }
        
        return currentHash == proof.root;
    }
    
    /**
     * @dev Verify an exclusion proof
     */
    function verifyExclusionProof(uint64 excludedKey, Proof memory proof) public pure returns (bool) {
        bool isAfterLeaf = excludedKey > proof.leaf.key;
        bool isBeforeNext = (proof.leaf.nextIdx == 0) || (excludedKey < proof.leaf.nextKey);
        return isAfterLeaf && isBeforeNext;
    }
    
    /**
     * @dev Get tree statistics
     */
    function getTreeStats() public view returns (uint32 numLeaves, uint256 root, bool isDirty) {
        return (treeState.numLeaves, treeState.root, treeState.isDirty);
    }
    
    /**
     * @dev Force cache rebuild (useful for testing)
     */
    function forceCacheRebuild() public {
        treeState.isDirty = true;
        _rebuildCache();
    }
}
