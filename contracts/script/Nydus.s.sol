// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Nydus} from "../src/Nydus.sol";
import {MiMCHasher} from "../src/MiMCHasher.sol";

contract NydusDeploy is Script {
    Nydus public nydus;
    MiMCHasher public hasher;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log("Deploying MiMCHasher...");
        hasher = new MiMCHasher();
        console.log("MiMCHasher deployed at:", address(hasher));

        console.log("Deploying Nydus contract...");
        // Use hardcoded Entry Verifier address (same as in test)
        address entryVerifier = 0x32695c99C385c618Ab388a904b8cfA19fb544d2F;
        
        address[] memory verifiers = new address[](1);
        verifiers[0] = entryVerifier;
        
        nydus = new Nydus(address(hasher), verifiers);
        console.log("Nydus deployed at:", address(nydus));

        console.log("Deployment completed successfully!");
        console.log("Nydus contract address:", address(nydus));
        console.log("MiMCHasher address:", address(hasher));
        console.log("Entry Verifier address (hardcoded):", entryVerifier);

        vm.stopBroadcast();
    }
}
