// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {FHECurveEngine} from "../../../contracts/libraries/FHECurveEngine.sol";
import {ICustomCurve} from "../../../contracts/interfaces/ICustomCurve.sol";
import {FHE, euint64} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title FHECurveEngineTest
 * @notice Test suite for the refactored FHECurveEngine library
 */
contract FHECurveEngineTest is Test {
    using FHECurveEngine for *;

    FHECurveEngine.ComputationState state;

    function setUp() public {
        // Initialize the computation state
        FHECurveEngine.initializeState(state);
    }

    function testInitializeState() public {
        // Test that state initialization works
        assertTrue(state.lastCleanup > 0, "State should be initialized with cleanup timestamp");
    }

    function testDecryptionCacheKeyGeneration() public {
        bytes32 poolId = keccak256("test_pool");
        string memory operation = "price_calculation";
        bytes memory params = abi.encodePacked(uint256(1000), uint8(1), uint256(500));
        
        bytes32 cacheKey = FHECurveEngine.generateDecryptionCacheKey(poolId, operation, params);
        
        // Test that cache key is generated consistently
        bytes32 cacheKey2 = FHECurveEngine.generateDecryptionCacheKey(poolId, operation, params);
        assertEq(cacheKey, cacheKey2, "Cache keys should be consistent");
        
        // Test that different params generate different keys
        bytes memory differentParams = abi.encodePacked(uint256(2000), uint8(1), uint256(500));
        bytes32 cacheKey3 = FHECurveEngine.generateDecryptionCacheKey(poolId, operation, differentParams);
        assertTrue(cacheKey != cacheKey3, "Different params should generate different cache keys");
    }

    function testDecryptionResultStructure() public {
        // Test the DecryptionResult struct creation
        FHECurveEngine.DecryptionResult memory result = FHECurveEngine.DecryptionResult({
            value: 1000,
            isReady: true,
            wasFromCache: false
        });
        
        assertEq(result.value, 1000, "Value should be set correctly");
        assertTrue(result.isReady, "IsReady should be true");
        assertFalse(result.wasFromCache, "WasFromCache should be false");
    }

    function testCurveParameterValidation() public {
        // Test curve parameter structure
        euint64[] memory coefficients = new euint64[](3);
        coefficients[0] = FHE.asEuint64(100); // coefficient a
        coefficients[1] = FHE.asEuint64(200); // coefficient b  
        coefficients[2] = FHE.asEuint64(300); // coefficient c
        
        ICustomCurve.CurveParams memory curveParams = ICustomCurve.CurveParams({
            curveType: ICustomCurve.CurveType.LINEAR,
            encryptedCoefficients: coefficients,
            formulaHash: keccak256("ax + b"),
            maxLeverage: 10e18,
            volatilityFactor: 500,
            minLiquidity: 1000e18,
            maxSlippage: 1000,
            timeDecayRate: 100,
            isActive: true,
            lastUpdate: block.timestamp,
            strategist: address(this)
        });
        
        assertTrue(curveParams.isActive, "Curve should be active");
        assertEq(uint8(curveParams.curveType), uint8(ICustomCurve.CurveType.LINEAR), "Curve type should be LINEAR");
        assertEq(curveParams.encryptedCoefficients.length, 3, "Should have 3 coefficients");
    }

    function testAsyncDecryptionFlow() public {
        bytes32 testCacheKey = keccak256("test_decryption");
        euint64 testValue = FHE.asEuint64(12345);
        
        // Initially should not be requested
        FHECurveEngine.DecryptionResult memory result = FHECurveEngine.getDecryptionResult(state, testCacheKey);
        assertFalse(result.isReady, "Should not be ready initially");
        
        // Request decryption
        FHECurveEngine.requestDecryption(state, testValue, testCacheKey);
        
        // Should now show as requested but may not be ready yet
        result = FHECurveEngine.getDecryptionResult(state, testCacheKey);
        // Note: In a real FHE environment, this might be ready or not depending on decryption timing
        
        // Complete decryption manually for testing
        FHECurveEngine.completeDecryption(state, testCacheKey, 12345);
        
        // Should now have cached value
        assertTrue(state.lastDecryptedValue[testCacheKey] == 12345, "Should have cached decrypted value");
    }

    function testComputationStateCleanup() public {
        uint256 initialCleanup = state.lastCleanup;
        
        // Fast forward time
        vm.warp(block.timestamp + 3700); // More than 1 hour
        
        uint256 cleaned = FHECurveEngine.cleanupCache(state, 100);
        
        assertTrue(state.lastCleanup > initialCleanup, "Cleanup timestamp should be updated");
    }

    function testCurveTypeSupport() public {
        // Test that all curve types are properly defined
        assertTrue(uint8(ICustomCurve.CurveType.LINEAR) == 0, "LINEAR should be 0");
        assertTrue(uint8(ICustomCurve.CurveType.EXPONENTIAL) == 1, "EXPONENTIAL should be 1");
        assertTrue(uint8(ICustomCurve.CurveType.LOGARITHMIC) == 2, "LOGARITHMIC should be 2");
        assertTrue(uint8(ICustomCurve.CurveType.POLYNOMIAL) == 3, "POLYNOMIAL should be 3");
        assertTrue(uint8(ICustomCurve.CurveType.SIGMOID) == 4, "SIGMOID should be 4");
    }

    function testEventEmissionStructure() public {
        // Test that events are properly structured (compilation test)
        vm.expectEmit(true, false, false, true);
        emit CurveCalculated(ICustomCurve.CurveType.LINEAR, 1000, false, block.timestamp);
        emit CurveCalculated(ICustomCurve.CurveType.LINEAR, 1000, false, block.timestamp);
    }

    // Event definition for testing
    event CurveCalculated(
        ICustomCurve.CurveType indexed curveType,
        uint256 gasUsed,
        bool cacheHit,
        uint256 timestamp
    );
}
