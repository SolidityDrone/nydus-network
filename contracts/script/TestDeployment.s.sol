// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HonkVerifier as EntryVerifier} from "../src/Verifiers/Verifier-Entry.sol";
import {HonkVerifier as SendVerifier} from "../src/Verifiers/Verifier-Send.sol";
import {HonkVerifier as AbsorbVerifier} from "../src/Verifiers/Verifier-Absorb.sol";

/**
 * @title TestDeployment
 * @notice Deploy all 3 verifiers at once
 */
contract TestDeployment is Script {
    
    function setUp() public {}
    
    function run() public {
        console.log("Deploying all 3 verifiers...");
        
        vm.startBroadcast();
        
        // Deploy Entry Verifier
        console.log("Deploying Entry Verifier...");
        EntryVerifier entryVerifier = new EntryVerifier();
        address entryAddress = address(entryVerifier);
        console.log("Entry Verifier deployed at:", entryAddress);
        
        // Deploy Send Verifier
        console.log("Deploying Send Verifier...");
        SendVerifier sendVerifier = new SendVerifier();
        address sendAddress = address(sendVerifier);
        console.log("Send Verifier deployed at:", sendAddress);
        
        // Deploy Absorb Verifier
        console.log("Deploying Absorb Verifier...");
        AbsorbVerifier absorbVerifier = new AbsorbVerifier();
        address absorbAddress = address(absorbVerifier);
        console.log("Absorb Verifier deployed at:", absorbAddress);
        
        vm.stopBroadcast();
        
        console.log("========================================");
        console.log("All 3 verifiers deployed successfully!");
        console.log("Entry Verifier:", entryAddress);
        console.log("Send Verifier:", sendAddress);
        console.log("Absorb Verifier:", absorbAddress);
        console.log("========================================");
    }
}
