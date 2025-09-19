// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title MockFHE
 * @notice Mock FHE library for testing without coprocessor
 * @dev Provides simplified implementations for testing
 */
library MockFHE {
    // Mock euint64 type - just wraps uint64
    struct euint64 {
        uint64 value;
        bool isEncrypted;
    }
    
    // Mock ebool type
    struct ebool {
        bool value;
    }
    
    function asEuint64(uint64 value) internal pure returns (euint64 memory) {
        return euint64(value, true);
    }
    
    function add(euint64 memory a, euint64 memory b) internal pure returns (euint64 memory) {
        return euint64(a.value + b.value, true);
    }
    
    function mul(euint64 memory a, euint64 memory b) internal pure returns (euint64 memory) {
        return euint64(a.value * b.value, true);
    }
    
    function div(euint64 memory a, euint64 memory b) internal pure returns (euint64 memory) {
        require(b.value != 0, "Division by zero");
        return euint64(a.value / b.value, true);
    }
    
    function gt(euint64 memory a, euint64 memory b) internal pure returns (ebool memory) {
        return ebool(a.value > b.value);
    }
    
    function lt(euint64 memory a, euint64 memory b) internal pure returns (ebool memory) {
        return ebool(a.value < b.value);
    }
    
    function decrypt(euint64 memory encrypted) internal pure returns (uint64) {
        return encrypted.value;
    }
    
    function decrypt(ebool memory encrypted) internal pure returns (bool) {
        return encrypted.value;
    }
}
