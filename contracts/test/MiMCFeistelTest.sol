// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MiMCHasher.sol";

/**
 * @title MiMCFeistelTest
 * @dev Test contract for MiMC-Feistel hasher
 */
contract MiMCFeistelTest is Test {
    MiMCHasher public mimcHasher;
    
    function setUp() public {
        mimcHasher = new MiMCHasher();
    }
    
    function testMiMCSponge() public {
        // Test with the same values as the Noir smoke test
        uint256 xL_in = 1234567890123456789012345678901234567890123456789012345678901234567890;
        uint256 xR_in = 9876543210987654321098765432109876543210987654321098765432109876543210;
        
        (uint256 xL_out, uint256 xR_out) = mimcHasher.MiMCSponge(xL_in, xR_in);
        
        // Verify outputs are not zero
        assertTrue(xL_out != 0, "xL output should not be zero");
        assertTrue(xR_out != 0, "xR output should not be zero");
        
        // Log the results for comparison with Noir
        console.log("MiMCSponge result (xL):", xL_out);
        console.log("MiMCSponge result (xR):", xR_out);
    }
    
    function testMiMCFeistel() public {
        // Test the individual Feistel function
        uint256 xL_in = 1234567890123456789012345678901234567890123456789012345678901234567890;
        uint256 xR_in = 9876543210987654321098765432109876543210987654321098765432109876543210;
        
        (uint256 xL_out, uint256 xR_out) = mimcHasher.MiMCFeistel(xL_in, xR_in, 0);
        
        // Verify outputs are not zero
        assertTrue(xL_out != 0, "xL output should not be zero");
        assertTrue(xR_out != 0, "xR output should not be zero");
        
        // Log the results for comparison with Noir
        console.log("MiMCFeistel result (xL):");
        console.logBytes(abi.encode(xL_out));
        console.log("MiMCFeistel result (xR):");
        console.logBytes(abi.encode(xR_out));

        assertEq(abi.encode(xL_out), hex'09f34e35e2aa44d1270de180df0c905c1c1ea51ca7f03fc4ded4775e70dd2e04');
        assertEq(abi.encode(xR_out), hex'1d739208ab77979344e98a48fe0e9aeff6176b471a718b1eca75d4158b612f19');


        // SAME VALUES YOU GET FROM lib.br in MiMC-feistel noir folder 
    }
    

}
