// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HonkVerifier} from "../src/Verifiers/Verifier-Entry.sol";

/**
 * @title TestDeployment
 * @notice Simple test script to verify deployment works
 */
contract TestDeployment is Script {
    
    function setUp() public {}
    
    function run() public {
        console.log("Testing verifier deployment...");
        
        vm.startBroadcast();
        
        // Test deployment
        HonkVerifier verifier = new HonkVerifier();
        address verifierAddress = address(verifier);
        
        console.log("Verifier deployed at:", verifierAddress);
        console.log("Verifier has code:", verifierAddress.code.length > 0);
        
        vm.stopBroadcast();
        
        console.log("Test deployment successful!");
    }
}
