// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IHasher
 * @dev Interface for MiMC-Feistel hasher
 */
interface IHasher {
    function MiMCSponge(uint256 in_xL, uint256 in_xR) external view returns (uint256 xL, uint256 xR);
}
