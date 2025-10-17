#!/bin/bash

# Test MiMCSponge function on Tornado Cash contract
# Contract: 0x83584f83f26af4edda9cbe8c730bc87c364b28fe
# Function: MiMCSponge(uint256 in_xL, uint256 in_xR) returns (uint256 xL, uint256 xR)

echo "Testing MiMCSponge on Tornado Cash contract..."

# Test with some sample inputs
# You can modify these values to test different inputs
IN_XL="1234567890123456789012345678901234567890123456789012345678901234567890"
IN_XR="9876543210987654321098765432109876543210987654321098765432109876543210"

echo "Input xL: $IN_XL"
echo "Input xR: $IN_XR"
echo ""

# Make the call using forge call
cast call 0x83584f83f26af4edda9cbe8c730bc87c364b28fe \
    "MiMCSponge(uint256,uint256)" \
    1234567890123456789012345678901234567890123456789012345678901234567890 9876543210987654321098765432109876543210987654321098765432109876543210 \
    --rpc-url https://1rpc.io/eth

echo ""
echo "You can also test with different inputs by modifying the IN_XL and IN_XR variables in this script."
