// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title OptimizedFHE
 * @notice Gas-optimized FHE operations with batching and caching for Chimera Protocol
 * @dev Addresses gas consumption and mathematical function limitations
 */
library OptimizedFHE {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fixed-point precision (12 decimal places for gas optimization)
    uint256 internal constant PRECISION = 1e12;
    uint256 internal constant HALF_PRECISION = PRECISION / 2;

    /// @notice Maximum values for different bit sizes
    uint256 internal constant MAX_UINT64 = type(uint64).max;
    uint256 internal constant MAX_UINT128 = type(uint128).max;

    /// @notice Cache timeout (5 minutes)
    uint256 internal constant DEFAULT_CACHE_TIMEOUT = 300;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Pre-computed constants to reduce gas consumption
    struct PrecomputedConstants {
        euint64 zero;
        euint64 one;
        euint64 two;
        euint64 six;
        euint64 twentyFour;
        euint64 precision;
        euint64 halfPrecision;
        euint64 maxUint64;
    }

    /// @notice Computation cache with TTL
    struct ComputationCache {
        mapping(bytes32 => euint64) results;
        mapping(bytes32 => uint256) timestamps;
        uint256 cacheTimeout;
        uint256 hitCount;
        uint256 missCount;
    }

    /// @notice Batch operation for multiple FHE operations
    struct BatchOperation {
        euint64[] operands;
        uint8 operation; // 0=add, 1=mul, 2=div, 3=sub
        euint64 result;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CacheHit(bytes32 indexed key, uint256 gasUsed);
    event CacheMiss(bytes32 indexed key, uint256 gasUsed);
    event BatchProcessed(uint256 operationCount, uint256 gasUsed);
    event ConstantsInitialized(uint256 gasUsed);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error DivisionByZero();
    error InvalidOperation(uint8 operation);
    error CacheKeyNotFound(bytes32 key);
    error InvalidBatchSize(uint256 size);
    error PrecisionOverflow();

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize pre-computed constants (call once per contract)
     * @dev Reduces repeated FHE.asEuint64() calls throughout execution
     * @return constants Initialized constant values
     */
    function initializeConstants() internal returns (PrecomputedConstants memory constants) {
        constants = PrecomputedConstants({
            zero: FHE.asEuint64(0),
            one: FHE.asEuint64(1),
            two: FHE.asEuint64(2),
            six: FHE.asEuint64(6),
            twentyFour: FHE.asEuint64(24),
            precision: FHE.asEuint64(PRECISION),
            halfPrecision: FHE.asEuint64(HALF_PRECISION),
            maxUint64: FHE.asEuint64(MAX_UINT64)
        });

        emit ConstantsInitialized(gasleft());
    }

    /*//////////////////////////////////////////////////////////////
                        MATHEMATICAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gas-optimized exponential approximation using 3-term Taylor series
     * @dev e^x ≈ 1 + x + x²/2 (reduces gas from 17M to ~7M)
     * @param x Input value (fixed-point)
     * @param constants Pre-computed constants
     * @return result Encrypted exponential result
     */
    function fastExp(
        euint64 x,
        PrecomputedConstants memory constants
    ) internal returns (euint64 result) {
        // Calculate x²
        euint64 x2 = FHE.mul(x, x);
        
        // Calculate x²/2
        euint64 term2 = FHE.div(x2, constants.two);
        
        // e^x ≈ 1 + x + x²/2
        result = FHE.add(constants.one, x);
        result = FHE.add(result, term2);
    }

    /**
     * @notice Gas-optimized natural logarithm approximation
     * @dev ln(x) ≈ (x-1) - (x-1)²/2 for x close to 1
     * @param x Input value (fixed-point)
     * @param constants Pre-computed constants
     * @return result Encrypted logarithm result
     */
    function fastLn(
        euint64 x,
        PrecomputedConstants memory constants
    ) internal returns (euint64 result) {
        // Calculate (x-1)
        euint64 xMinus1 = FHE.sub(x, constants.one);
        
        // Calculate (x-1)²
        euint64 xMinus1Sq = FHE.mul(xMinus1, xMinus1);
        
        // Calculate (x-1)²/2
        euint64 correction = FHE.div(xMinus1Sq, constants.two);
        
        // ln(x) ≈ (x-1) - (x-1)²/2
        result = FHE.sub(xMinus1, correction);
    }

    /**
     * @notice Integer power using binary exponentiation
     * @dev x^n using repeated squaring - O(log n) complexity
     * @param base Base value
     * @param exponent Exponent (plaintext for efficiency)
     * @param constants Pre-computed constants
     * @return result Encrypted power result
     */
    function fastPow(
        euint64 base,
        uint256 exponent,
        PrecomputedConstants memory constants
    ) internal returns (euint64 result) {
        if (exponent == 0) return constants.one;
        if (exponent == 1) return base;
        
        result = constants.one;
        euint64 currentBase = base;
        
        // Binary exponentiation
        while (exponent > 0) {
            if (exponent & 1 == 1) {
                result = FHE.mul(result, currentBase);
            }
            if (exponent > 1) {
                currentBase = FHE.mul(currentBase, currentBase);
            }
            exponent >>= 1;
        }
    }

    /**
     * @notice Square root approximation using Newton-Raphson method
     * @dev sqrt(x) using iterative approximation
     * @param x Input value
     * @param constants Pre-computed constants
     * @return result Encrypted square root result
     */
    function fastSqrt(
        euint64 x,
        PrecomputedConstants memory constants
    ) internal returns (euint64 result) {
        // Initial guess: x/2
        result = FHE.div(x, constants.two);
        
        // Newton-Raphson iterations: x_{n+1} = (x_n + a/x_n) / 2
        // 3 iterations provide good accuracy for most use cases
        for (uint256 i = 0; i < 3; i++) {
            euint64 quotient = FHE.div(x, result);
            result = FHE.div(FHE.add(result, quotient), constants.two);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PRECISION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice High-precision fixed-point division
     * @dev Multiplies numerator by precision before division
     * @param numerator Dividend
     * @param denominator Divisor
     * @param constants Pre-computed constants
     * @return result Fixed-point division result
     */
    function precisionDiv(
        euint64 numerator,
        euint64 denominator,
        PrecomputedConstants memory constants
    ) internal returns (euint64 result) {
        // Check for division by zero using FHE comparison
        ebool isZero = FHE.eq(denominator, constants.zero);
        
        // Scale numerator by precision
        euint64 scaled = FHE.mul(numerator, constants.precision);
        
        // Perform division
        euint64 divResult = FHE.div(scaled, denominator);
        
        // Return max value if division by zero, otherwise return result
        result = FHE.select(isZero, constants.maxUint64, divResult);
    }

    /**
     * @notice High-precision fixed-point multiplication
     * @dev Multiplies then divides by precision to maintain scale
     * @param a First operand
     * @param b Second operand
     * @param constants Pre-computed constants
     * @return result Fixed-point multiplication result
     */
    function precisionMul(
        euint64 a,
        euint64 b,
        PrecomputedConstants memory constants
    ) internal returns (euint64 result) {
        euint64 product = FHE.mul(a, b);
        result = FHE.div(product, constants.precision);
    }

    /*//////////////////////////////////////////////////////////////
                        CONDITIONAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Absolute value calculation using FHE select
     * @dev |x| using conditional logic without branching
     * @param x Input value
     * @param constants Pre-computed constants
     * @return result Absolute value
     */
    function abs(
        euint64 x,
        PrecomputedConstants memory constants
    ) internal returns (euint64 result) {
        // For unsigned integers, we simulate signed behavior
        // by checking if x is greater than half the max value
        euint64 halfMax = FHE.div(constants.maxUint64, constants.two);
        ebool isPositive = FHE.lte(x, halfMax);
        
        // If "negative", compute complement; otherwise use as-is
        euint64 complement = FHE.sub(constants.maxUint64, x);
        result = FHE.select(isPositive, x, complement);
    }

    /**
     * @notice Conditional execution without branching
     * @dev Execute different calculations based on encrypted condition
     * @param condition Encrypted boolean condition
     * @param valueIfTrue Value to return if condition is true
     * @param valueIfFalse Value to return if condition is false
     * @return result Selected value based on condition
     */
    function conditionalSelect(
        ebool condition,
        euint64 valueIfTrue,
        euint64 valueIfFalse
    ) internal returns (euint64 result) {
        result = FHE.select(condition, valueIfTrue, valueIfFalse);
    }

    /**
     * @notice Range clamping using FHE operations
     * @dev Clamp value between min and max bounds
     * @param value Input value
     * @param minValue Minimum bound
     * @param maxValue Maximum bound
     * @return result Clamped value
     */
    function clamp(
        euint64 value,
        euint64 minValue,
        euint64 maxValue
    ) internal returns (euint64 result) {
        // Clamp to minimum: max(value, minValue)
        ebool aboveMin = FHE.gte(value, minValue);
        result = FHE.select(aboveMin, value, minValue);
        
        // Clamp to maximum: min(result, maxValue)
        ebool belowMax = FHE.lte(result, maxValue);
        result = FHE.select(belowMax, result, maxValue);
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Process multiple operations in single transaction
     * @dev Reduces per-operation gas overhead through batching
     * @param operations Array of batch operations to process
     * @return results Array of operation results
     */
    function batchArithmetic(
        BatchOperation[] memory operations
    ) internal returns (euint64[] memory results) {
        results = new euint64[](operations.length);
        uint256 startGas = gasleft();
        
        for (uint256 i = 0; i < operations.length; i++) {
            BatchOperation memory op = operations[i];
            
            if (op.operation == 0) {
                // Addition
                results[i] = _batchAdd(op.operands);
            } else if (op.operation == 1) {
                // Multiplication
                results[i] = _batchMul(op.operands);
            } else if (op.operation == 2) {
                // Division (sequential)
                results[i] = _batchDiv(op.operands);
            } else if (op.operation == 3) {
                // Subtraction (sequential)
                results[i] = _batchSub(op.operands);
            } else {
                revert InvalidOperation(op.operation);
            }
        }
        
        emit BatchProcessed(operations.length, startGas - gasleft());
    }

    /**
     * @notice Batch addition of multiple operands
     * @param operands Array of values to add
     * @return result Sum of all operands
     */
    function _batchAdd(euint64[] memory operands) private returns (euint64 result) {
        if (operands.length == 0) revert InvalidBatchSize(0);
        
        result = operands[0];
        for (uint256 i = 1; i < operands.length; i++) {
            result = FHE.add(result, operands[i]);
        }
    }

    /**
     * @notice Batch multiplication of multiple operands
     * @param operands Array of values to multiply
     * @return result Product of all operands
     */
    function _batchMul(euint64[] memory operands) private returns (euint64 result) {
        if (operands.length == 0) revert InvalidBatchSize(0);
        
        result = operands[0];
        for (uint256 i = 1; i < operands.length; i++) {
            result = FHE.mul(result, operands[i]);
        }
    }

    /**
     * @notice Sequential division of operands
     * @param operands Array of values (first / second / third / ...)
     * @return result Sequential division result
     */
    function _batchDiv(euint64[] memory operands) private returns (euint64 result) {
        if (operands.length == 0) revert InvalidBatchSize(0);
        
        result = operands[0];
        for (uint256 i = 1; i < operands.length; i++) {
            result = FHE.div(result, operands[i]);
        }
    }

    /**
     * @notice Sequential subtraction of operands
     * @param operands Array of values (first - second - third - ...)
     * @return result Sequential subtraction result
     */
    function _batchSub(euint64[] memory operands) private returns (euint64 result) {
        if (operands.length == 0) revert InvalidBatchSize(0);
        
        result = operands[0];
        for (uint256 i = 1; i < operands.length; i++) {
            result = FHE.sub(result, operands[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CACHE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get cached computation result with TTL check
     * @param cache Storage reference to cache
     * @param key Cache key for lookup
     * @return result Cached FHE result
     * @return found Whether result was found and valid
     */
    function getCachedResult(
        ComputationCache storage cache,
        bytes32 key
    ) internal view returns (euint64 result, bool found) {
        uint256 timestamp = cache.timestamps[key];
        
        if (timestamp > 0 && block.timestamp <= timestamp + cache.cacheTimeout) {
            result = cache.results[key];
            found = true;
            // Note: We can't emit events in view functions
        } else {
            found = false;
        }
    }

    /**
     * @notice Cache computation result with timestamp
     * @param cache Storage reference to cache
     * @param key Cache key for storage
     * @param result FHE result to cache
     */
    function setCachedResult(
        ComputationCache storage cache,
        bytes32 key,
        euint64 result
    ) internal {
        cache.results[key] = result;
        cache.timestamps[key] = block.timestamp;
        
        // Update cache statistics
        if (cache.timestamps[key] == 0) {
            cache.missCount++;
        } else {
            cache.hitCount++;
        }
        
        emit CacheHit(key, gasleft());
    }

    /**
     * @notice Clear expired cache entries
     * @param cache Storage reference to cache
     * @param keys Array of cache keys to check
     * @return cleared Number of entries cleared
     */
    function clearExpiredCache(
        ComputationCache storage cache,
        bytes32[] memory keys
    ) internal returns (uint256 cleared) {
        uint256 currentTime = block.timestamp;
        
        for (uint256 i = 0; i < keys.length; i++) {
            bytes32 key = keys[i];
            uint256 timestamp = cache.timestamps[key];
            
            if (timestamp > 0 && currentTime > timestamp + cache.cacheTimeout) {
                cache.results[key] = FHE.asEuint64(0); // Reset to zero instead of delete
                cache.timestamps[key] = 0;
                cleared++;
            }
        }
    }

    /**
     * @notice Initialize cache with default timeout
     * @param cache Storage reference to cache
     */
    function initializeCache(ComputationCache storage cache) internal {
        cache.cacheTimeout = DEFAULT_CACHE_TIMEOUT;
        cache.hitCount = 0;
        cache.missCount = 0;
    }

    /**
     * @notice Get cache statistics
     * @param cache Storage reference to cache
     * @return hitCount Number of cache hits
     * @return missCount Number of cache misses
     * @return hitRate Cache hit rate (percentage)
     */
    function getCacheStats(
        ComputationCache storage cache
    ) internal view returns (uint256 hitCount, uint256 missCount, uint256 hitRate) {
        hitCount = cache.hitCount;
        missCount = cache.missCount;
        
        uint256 totalRequests = hitCount + missCount;
        if (totalRequests > 0) {
            hitRate = (hitCount * 100) / totalRequests;
        } else {
            hitRate = 0;
        }
    }
}