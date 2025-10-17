// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Nydus} from "../src/Nydus.sol";
contract NydusTest is Test {
    Nydus public nydus;

    function setUp() public {
        nydus = new Nydus();
    }

    function test_Nydus() public {
        assertEq(nydus.name(), "Nydus");
    }
}
