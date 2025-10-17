// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IndexedMerkleTreeMiMCCached.sol";

/**
 * @title Nydus
 * @dev Main Nydus contract that inherits from IndexedMerkleTreeMiMCCached
 * @notice Provides historical root storage and enhanced merkle tree functionality
 */
contract Nydus is IndexedMerkleTreeMiMCCached {
    
    // Historical root storage
    struct HistoricalRoot {
        uint256 root;
        uint32 leafCount;
        uint256 timestamp;
        uint32 leafIdx;
    }
    
    // Mapping from root hash to historical root data
    mapping(uint256 => HistoricalRoot) public historicalRoots;
    mapping(bytes32 => bool) public knownNonceCommitments;


    // Array to track all root hashes for iteration
    uint256[] public rootHashes;
    
    // Counter for total historical roots
    uint256 public totalHistoricalRoots;
    
    // Events for historical tracking
    event HistoricalRootStored(uint256 indexed root, uint32 leafCount, uint256 timestamp, uint32 leafIdx);
    event LeafInsertedWithHistory(uint32 leafIdx, uint64 key, uint256 value, uint256 newRoot, uint256 historicalIndex);
    
    constructor(address _hasher) IndexedMerkleTreeMiMCCached(_hasher) {
        // Store the initial empty root
        _storeHistoricalRoot(0, 0, 0);
    }
    
    /**
     * @dev Store a historical root entry
     * @param root The merkle root to store
     * @param leafCount Number of leaves when this root was created
     * @param leafIdx The leaf index that triggered this root
     */
    function _storeHistoricalRoot(uint256 root, uint32 leafCount, uint32 leafIdx) internal {
        // Only store if this root doesn't already exist
        if (historicalRoots[root].timestamp == 0) {
            historicalRoots[root] = HistoricalRoot({
                root: root,
                leafCount: leafCount,
                timestamp: block.timestamp,
                leafIdx: leafIdx
            });
            
            rootHashes.push(root);
            totalHistoricalRoots++;
            
            emit HistoricalRootStored(root, leafCount, block.timestamp, leafIdx);
        }
    }
    
    /**
     * @dev Insert a leaf and store historical root
     * @param key The key for the leaf
     * @param value The value for the leaf
     * @return leafIdx The index of the inserted leaf
     * @return newRoot The new merkle root
     * @return wasStored Whether the historical root was actually stored
     */
    function insertLeafWithHistory(uint64 key, uint256 value) public returns (
        uint32 leafIdx, 
        uint256 newRoot, 
        bool wasStored
    ) {
        // Call parent insertLeaf method
        (leafIdx, newRoot) = insertLeaf(key, value);
        
        // Store the historical root (returns whether it was actually stored)
        uint256 previousCount = totalHistoricalRoots;
        _storeHistoricalRoot(newRoot, treeState.numLeaves, leafIdx);
        wasStored = totalHistoricalRoots > previousCount;
        
        emit LeafInsertedWithHistory(leafIdx, key, value, newRoot, totalHistoricalRoots - 1);
    }
    
    /**
     * @dev Check if a historical root exists
     * @param root The root hash to check
     * @return exists True if the root exists in historical data
     */
    function isHistoricalRoot(uint256 root) public view returns (bool exists) {
        return historicalRoots[root].timestamp != 0;
    }
    
    /**
     * @dev Get historical root data by root hash
     * @param root The root hash to look up
     * @return leafCount Number of leaves at that point
     * @return timestamp When this root was created
     * @return leafIdx The leaf index that triggered this root
     */
    function getHistoricalRootData(uint256 root) public view returns (
        uint32 leafCount,
        uint256 timestamp,
        uint32 leafIdx
    ) {
        require(isHistoricalRoot(root), "Historical root does not exist");
        
        HistoricalRoot memory historicalRoot = historicalRoots[root];
        return (
            historicalRoot.leafCount,
            historicalRoot.timestamp,
            historicalRoot.leafIdx
        );
    }
    
    /**
     * @dev Get the total number of historical roots
     * @return count Number of historical roots stored
     */
    function getHistoricalRootCount() public view returns (uint256 count) {
        return totalHistoricalRoots;
    }
    
    /**
     * @dev Get a specific historical root by index in the rootHashes array
     * @param index The index in the rootHashes array
     * @return root The root hash at that index
     * @return leafCount Number of leaves at that point
     * @return timestamp When this root was created
     * @return leafIdx The leaf index that triggered this root
     */
    function getHistoricalRootByIndex(uint256 index) public view returns (
        uint256 root,
        uint32 leafCount,
        uint256 timestamp,
        uint32 leafIdx
    ) {
        require(index < rootHashes.length, "Historical root index out of bounds");
        
        root = rootHashes[index];
        HistoricalRoot memory historicalRoot = historicalRoots[root];
        return (
            root,
            historicalRoot.leafCount,
            historicalRoot.timestamp,
            historicalRoot.leafIdx
        );
    }
    
    /**
     * @dev Get the latest historical root
     * @return root The latest historical root
     * @return leafCount Number of leaves
     * @return timestamp When this root was created
     * @return leafIdx The leaf index that triggered this root
     */
    function getLatestHistoricalRoot() public view returns (
        uint256 root,
        uint32 leafCount,
        uint256 timestamp,
        uint32 leafIdx
    ) {
        require(rootHashes.length > 0, "No historical roots available");
        
        root = rootHashes[rootHashes.length - 1];
        HistoricalRoot memory latest = historicalRoots[root];
        return (
            root,
            latest.leafCount,
            latest.timestamp,
            latest.leafIdx
        );
    }
    /**
     * @dev Override insertLeaf to automatically store historical roots
     * @param key The key for the leaf
     * @param value The value for the leaf
     * @return leafIdx The index of the inserted leaf
     * @return newRoot The new merkle root
     */
    function insertLeaf(uint64 key, uint256 value) public override returns (uint32 leafIdx, uint256 newRoot)  {
        // Call parent method
        (leafIdx, newRoot) = super.insertLeaf(key, value);
        
        // Store historical root
        _storeHistoricalRoot(newRoot, treeState.numLeaves, leafIdx);
        
        emit LeafInsertedWithHistory(leafIdx, key, value, newRoot, totalHistoricalRoots - 1);
    }
}