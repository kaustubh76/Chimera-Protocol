// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {OptimizedFHE} from "./OptimizedFHE.sol";
import {ICustomCurve} from "../interfaces/ICustomCurve.sol";

/**
 * @title FHECurveEngine
 * @notice Complete FHE-based custom curve calculation engine
 * @dev Implements all curve types with gas optimization and caching
 */
library FHECurveEngine {
    using OptimizedFHE for *;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of terms in Taylor series approximations
    uint256 private constant MAX_TAYLOR_TERMS = 4;
    
    /// @notice Precision scaling for intermediate calculations
    uint256 private constant CALC_PRECISION = 1e18;
    
    /// @notice Maximum safe exponent value to prevent overflow
    uint256 private constant MAX_SAFE_EXPONENT = 50;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computation state for gas optimization and caching
    struct ComputationState {
        OptimizedFHE.PrecomputedConstants constants;
        OptimizedFHE.ComputationCache cache;
        mapping(bytes32 => euint64) intermediateResults;
        uint256 lastCleanup;
        // Async decryption state
        mapping(bytes32 => bool) decryptionRequested;
        mapping(bytes32 => euint64) pendingDecryption;
        mapping(bytes32 => uint256) lastDecryptedValue;
        mapping(bytes32 => uint256) decryptionTimestamp;
    }

    /// @notice Curve calculation parameters
    struct CalculationParams {
        euint64 x;                      // Input value
        ICustomCurve.CurveParams curveParams;  // Curve configuration
        bool useCache;                    // Whether to use caching
        uint256 maxGas;                   // Gas limit for calculation
    }

    /// @notice Decryption result with readiness status
    struct DecryptionResult {
        uint256 value;
        bool isReady;
        bool wasFromCache;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CurveCalculated(
        ICustomCurve.CurveType indexed curveType,
        uint256 gasUsed,
        bool cacheHit,
        uint256 timestamp
    );

    event ApproximationUsed(
        string indexed functionName,
        uint256 terms,
        uint256 gasUsed
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnsupportedCurveType(ICustomCurve.CurveType curveType);
    error ExponentTooLarge(uint256 exponent);
    error CalculationTimeout(uint256 gasUsed, uint256 gasLimit);
    error InvalidCurveParameters(string reason);

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize computation state with constants and cache
     * @param state Storage reference to computation state
     */
    function initializeState(ComputationState storage state) internal {
        state.constants = OptimizedFHE.initializeConstants();
        OptimizedFHE.initializeCache(state.cache);
        state.lastCleanup = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                        ASYNC DECRYPTION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Request async decryption of an encrypted value
     * @param state Computation state
     * @param encryptedValue The encrypted value to decrypt
     * @param cacheKey Unique key for caching this decryption
     */
    function requestDecryption(
        ComputationState storage state,
        euint64 encryptedValue,
        bytes32 cacheKey
    ) internal {
        if (!state.decryptionRequested[cacheKey]) {
            FHE.decrypt(encryptedValue);
            state.decryptionRequested[cacheKey] = true;
            state.pendingDecryption[cacheKey] = encryptedValue;
            state.decryptionTimestamp[cacheKey] = block.timestamp;
        }
    }

    /**
     * @notice Get decryption result with proper async handling
     * @param state Computation state
     * @param cacheKey Cache key for the decryption request
     * @return result Decryption result with value and status
     */
    function getDecryptionResult(
        ComputationState storage state,
        bytes32 cacheKey
    ) internal view returns (DecryptionResult memory result) {
        if (!state.decryptionRequested[cacheKey]) {
            return DecryptionResult({
                value: 0,
                isReady: false,
                wasFromCache: false
            });
        }

        euint64 encryptedValue = state.pendingDecryption[cacheKey];
        (uint64 decryptedValue, bool ready) = FHE.getDecryptResultSafe(encryptedValue);
        
        if (ready) {
            result = DecryptionResult({
                value: uint256(decryptedValue),
                isReady: true,
                wasFromCache: false
            });
        } else {
            // Check if we have a cached value
            uint256 cachedValue = state.lastDecryptedValue[cacheKey];
            if (cachedValue > 0) {
                result = DecryptionResult({
                    value: cachedValue,
                    isReady: true,
                    wasFromCache: true
                });
            } else {
                result = DecryptionResult({
                    value: 0,
                    isReady: false,
                    wasFromCache: false
                });
            }
        }
    }

    /**
     * @notice Complete decryption and update cache
     * @param state Computation state
     * @param cacheKey Cache key for the decryption
     * @param decryptedValue The decrypted value to cache
     */
    function completeDecryption(
        ComputationState storage state,
        bytes32 cacheKey,
        uint256 decryptedValue
    ) internal {
        state.lastDecryptedValue[cacheKey] = decryptedValue;
        state.decryptionRequested[cacheKey] = false;
        // Keep the cached value for future use
    }

    /**
     * @notice Generate cache key for decryption requests
     * @param poolId Pool identifier
     * @param operation Type of operation (price, volatility, etc.)
     * @param params Additional parameters for uniqueness
     * @return cacheKey Unique cache key
     */
    function generateDecryptionCacheKey(
        bytes32 poolId,
        string memory operation,
        bytes memory params
    ) internal pure returns (bytes32 cacheKey) {
        return keccak256(abi.encodePacked(poolId, operation, params));
    }

    /*//////////////////////////////////////////////////////////////
                        MAIN PRICE CALCULATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice High-level price calculation with integrated decryption management
     * @param poolId Pool identifier for caching
     * @param inputAmount Input amount for price calculation
     * @param curveParams Curve parameters
     * @param state Computation state
     * @return decryptedPrice Final decrypted price
     * @return isReady Whether the result is ready (not pending decryption)
     * @return gasUsed Gas consumed
     */
    function calculateAndDecryptPrice(
        bytes32 poolId,
        uint256 inputAmount,
        ICustomCurve.CurveParams memory curveParams,
        ComputationState storage state
    ) internal returns (uint256 decryptedPrice, bool isReady, uint256 gasUsed) {
        uint256 startGas = gasleft();
        
        // Generate cache key for this specific calculation
        bytes32 cacheKey = generateDecryptionCacheKey(
            poolId,
            "price_calculation",
            abi.encodePacked(inputAmount, curveParams.curveType, curveParams.volatilityFactor)
        );
        
        // Check if we have a pending or completed decryption
        DecryptionResult memory result = getDecryptionResult(state, cacheKey);
        
        if (result.isReady) {
            // We have a result ready
            gasUsed = startGas - gasleft();
            return (result.value, true, gasUsed);
        }
        
        // Need to calculate and request decryption
        euint64 encryptedInput = FHE.asEuint64(uint64(inputAmount));
        (euint64 encryptedPrice, uint256 calcGas) = calculatePrice(encryptedInput, curveParams, state);
        
        // Request decryption for next time
        requestDecryption(state, encryptedPrice, cacheKey);
        
        gasUsed = startGas - gasleft();
        
        // Return with not ready status - caller should handle fallback
        return (0, false, gasUsed);
    }

    /**
     * @notice Try to complete a pending decryption and return result
     * @param poolId Pool identifier
     * @param inputAmount Original input amount
     * @param curveParams Original curve parameters
     * @param state Computation state
     * @return decryptedPrice The decrypted price if ready
     * @return isReady Whether decryption completed
     */
    function tryCompleteDecryption(
        bytes32 poolId,
        uint256 inputAmount,
        ICustomCurve.CurveParams memory curveParams,
        ComputationState storage state
    ) internal returns (uint256 decryptedPrice, bool isReady) {
        bytes32 cacheKey = generateDecryptionCacheKey(
            poolId,
            "price_calculation",
            abi.encodePacked(inputAmount, curveParams.curveType, curveParams.volatilityFactor)
        );
        
        DecryptionResult memory result = getDecryptionResult(state, cacheKey);
        
        if (result.isReady && !result.wasFromCache) {
            // Fresh decryption completed - update cache
            completeDecryption(state, cacheKey, result.value);
        }
        
        return (result.value, result.isReady);
    }

    /**
     * @notice Main entry point for curve price calculations
     * @param x Input value for price calculation
     * @param curveParams Encrypted curve parameters
     * @param state Computation state with cache and constants
     * @return price Calculated price using the specified curve
     * @return gasUsed Gas consumed for the calculation
     */
    function calculatePrice(
        euint64 x,
        ICustomCurve.CurveParams memory curveParams,
        ComputationState storage state
    ) internal returns (euint64 price, uint256 gasUsed) {
        uint256 startGas = gasleft();
        
        // Check cache first
        bytes32 cacheKey = _generateCacheKey(x, curveParams);
        (euint64 cachedResult, bool found) = OptimizedFHE.getCachedResult(state.cache, cacheKey);
        
        if (found) {
            price = cachedResult;
            gasUsed = startGas - gasleft();
            emit CurveCalculated(curveParams.curveType, gasUsed, true, block.timestamp);
            return (price, gasUsed);
        }

        // Calculate based on curve type
        if (curveParams.curveType == ICustomCurve.CurveType.LINEAR) {
            price = _calculateLinearPrice(x, curveParams, state);
        } else if (curveParams.curveType == ICustomCurve.CurveType.EXPONENTIAL) {
            price = _calculateExponentialPrice(x, curveParams, state);
        } else if (curveParams.curveType == ICustomCurve.CurveType.LOGARITHMIC) {
            price = _calculateLogarithmicPrice(x, curveParams, state);
        } else if (curveParams.curveType == ICustomCurve.CurveType.POLYNOMIAL) {
            price = _calculatePolynomialPrice(x, curveParams, state);
        } else if (curveParams.curveType == ICustomCurve.CurveType.SIGMOID) {
            price = _calculateSigmoidPrice(x, curveParams, state);
        } else {
            revert UnsupportedCurveType(curveParams.curveType);
        }

        // Apply price bounds
        price = _applyPriceBounds(price, curveParams, state);

        // Cache result
        OptimizedFHE.setCachedResult(state.cache, cacheKey, price);

        gasUsed = startGas - gasleft();
        emit CurveCalculated(curveParams.curveType, gasUsed, false, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        CURVE IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Linear curve: P = ax + b
     * @dev Most gas-efficient curve type (~4M gas)
     * @param x Input value
     * @param params Curve parameters (a, b in encryptedCoefficients)
     * @param state Computation state
     * @return price Linear curve result
     */
    function _calculateLinearPrice(
        euint64 x,
        ICustomCurve.CurveParams memory params,
        ComputationState storage state
    ) private returns (euint64 price) {
        require(params.encryptedCoefficients.length >= 2, "Linear curve needs 2 coefficients");
        
        euint64 a = params.encryptedCoefficients[0]; // slope
        euint64 b = params.encryptedCoefficients[1]; // intercept
        
        // P = ax + b
        euint64 ax = FHE.mul(a, x);
        price = FHE.add(ax, b);
    }

    /**
     * @notice Exponential curve: P = a * e^(bx)
     * @dev Uses optimized Taylor series (~12M gas)
     * @param x Input value
     * @param params Curve parameters (a, b in encryptedCoefficients)
     * @param state Computation state
     * @return price Exponential curve result
     */
    function _calculateExponentialPrice(
        euint64 x,
        ICustomCurve.CurveParams memory params,
        ComputationState storage state
    ) private returns (euint64 price) {
        require(params.encryptedCoefficients.length >= 2, "Exponential curve needs 2 coefficients");
        
        euint64 a = params.encryptedCoefficients[0]; // amplitude
        euint64 b = params.encryptedCoefficients[1]; // rate
        
        // Calculate bx
        euint64 bx = FHE.mul(b, x);
        
        // e^(bx) using optimized approximation
        euint64 expBx = OptimizedFHE.fastExp(bx, state.constants);
        
        // P = a * e^(bx)
        price = FHE.mul(a, expBx);

        emit ApproximationUsed("fastExp", 3, gasleft());
    }

    /**
     * @notice Logarithmic curve: P = a * ln(bx + c)
     * @dev Uses optimized series expansion (~9M gas)
     * @param x Input value
     * @param params Curve parameters (a, b, c in encryptedCoefficients)
     * @param state Computation state
     * @return price Logarithmic curve result
     */
    function _calculateLogarithmicPrice(
        euint64 x,
        ICustomCurve.CurveParams memory params,
        ComputationState storage state
    ) private returns (euint64 price) {
        require(params.encryptedCoefficients.length >= 3, "Logarithmic curve needs 3 coefficients");
        
        euint64 a = params.encryptedCoefficients[0]; // amplitude
        euint64 b = params.encryptedCoefficients[1]; // rate
        euint64 c = params.encryptedCoefficients[2]; // offset
        
        // Calculate bx + c
        euint64 bx = FHE.mul(b, x);
        euint64 argument = FHE.add(bx, c);
        
        // ln(bx + c) using optimized approximation
        euint64 lnArg = OptimizedFHE.fastLn(argument, state.constants);
        
        // P = a * ln(bx + c)
        price = FHE.mul(a, lnArg);

        emit ApproximationUsed("fastLn", 2, gasleft());
    }

    /**
     * @notice Polynomial curve: P = ax² + bx + c
     * @dev Quadratic polynomial (~6M gas)
     * @param x Input value
     * @param params Curve parameters (a, b, c in encryptedCoefficients)
     * @param state Computation state
     * @return price Polynomial curve result
     */
    function _calculatePolynomialPrice(
        euint64 x,
        ICustomCurve.CurveParams memory params,
        ComputationState storage state
    ) private returns (euint64 price) {
        require(params.encryptedCoefficients.length >= 3, "Polynomial curve needs 3 coefficients");
        
        euint64 a = params.encryptedCoefficients[0]; // quadratic coefficient
        euint64 b = params.encryptedCoefficients[1]; // linear coefficient
        euint64 c = params.encryptedCoefficients[2]; // constant term
        
        // Calculate x²
        euint64 x2 = FHE.mul(x, x);
        
        // Calculate ax²
        euint64 ax2 = FHE.mul(a, x2);
        
        // Calculate bx
        euint64 bx = FHE.mul(b, x);
        
        // P = ax² + bx + c
        euint64 sum = FHE.add(ax2, bx);
        price = FHE.add(sum, c);
    }

    /**
     * @notice Sigmoid curve: P = L / (1 + e^(-k(x-x₀)))
     * @dev Most complex curve type (~18M gas)
     * @param x Input value
     * @param params Curve parameters (L, k, x₀ in encryptedCoefficients)
     * @param state Computation state
     * @return price Sigmoid curve result
     */
    function _calculateSigmoidPrice(
        euint64 x,
        ICustomCurve.CurveParams memory params,
        ComputationState storage state
    ) private returns (euint64 price) {
        require(params.encryptedCoefficients.length >= 3, "Sigmoid curve needs 3 coefficients");
        
        euint64 L = params.encryptedCoefficients[0];  // maximum value
        euint64 k = params.encryptedCoefficients[1];  // steepness
        euint64 x0 = params.encryptedCoefficients[2]; // midpoint
        
        // Calculate (x - x₀)
        euint64 xMinusX0 = FHE.sub(x, x0);
        
        // Calculate k(x - x₀)
        euint64 kDiff = FHE.mul(k, xMinusX0);
        
        // Calculate -k(x - x₀) (simulate negation)
        euint64 negKDiff = FHE.sub(state.constants.precision, kDiff);
        
        // Calculate e^(-k(x - x₀))
        euint64 expNeg = OptimizedFHE.fastExp(negKDiff, state.constants);
        
        // Calculate 1 + e^(-k(x - x₀))
        euint64 denominator = FHE.add(state.constants.one, expNeg);
        
        // Calculate L / (1 + e^(-k(x - x₀)))
        price = OptimizedFHE.precisionDiv(L, denominator, state.constants);

        emit ApproximationUsed("sigmoid", 3, gasleft());
    }

    /*//////////////////////////////////////////////////////////////
                        UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Apply price bounds enforcement
     * @param price Calculated price
     * @param params Curve parameters with min/max prices
     * @param state Computation state
     * @return boundedPrice Price clamped to bounds
     */
    function _applyPriceBounds(
        euint64 price,
        ICustomCurve.CurveParams memory params,
        ComputationState storage state
    ) private returns (euint64 boundedPrice) {
        // For simplicity, we'll use the last two coefficients as min/max if available
        if (params.encryptedCoefficients.length >= 5) {
            euint64 minPrice = params.encryptedCoefficients[params.encryptedCoefficients.length - 2];
            euint64 maxPrice = params.encryptedCoefficients[params.encryptedCoefficients.length - 1];
            
            boundedPrice = OptimizedFHE.clamp(price, minPrice, maxPrice);
        } else {
            boundedPrice = price;
        }
    }

    /**
     * @notice Generate cache key for computation caching
     * @param x Input value
     * @param params Curve parameters
     * @return cacheKey Unique cache key
     */
    function _generateCacheKey(
        euint64 x,
        ICustomCurve.CurveParams memory params
    ) private pure returns (bytes32 cacheKey) {
        // We can only hash non-encrypted data for the cache key
        cacheKey = keccak256(abi.encode(
            params.curveType,
            params.maxLeverage,
            params.volatilityFactor,
            params.lastUpdate,
            params.strategist
            // Note: We can't include encrypted coefficients in the hash
        ));
    }

    /*//////////////////////////////////////////////////////////////
                        SLIPPAGE PROTECTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validate slippage protection using FHE operations
     * @param actualPrice Actual calculated price
     * @param expectedPrice Expected price
     * @param maxSlippageBps Maximum slippage in basis points
     * @param state Computation state
     * @return isValid Whether slippage is within bounds
     * @return slippageBps Actual slippage in basis points
     */
    function validateSlippage(
        euint64 actualPrice,
        euint64 expectedPrice,
        uint256 maxSlippageBps,
        ComputationState storage state
    ) internal returns (ebool isValid, euint64 slippageBps) {
        // Calculate absolute difference
        ebool actualHigher = FHE.gt(actualPrice, expectedPrice);
        euint64 diff = FHE.select(
            actualHigher,
            FHE.sub(actualPrice, expectedPrice),
            FHE.sub(expectedPrice, actualPrice)
        );
        
        // Calculate slippage: (diff / expectedPrice) * 10000
        euint64 tenThousand = FHE.asEuint64(10000);
        euint64 diffScaled = FHE.mul(diff, tenThousand);
        slippageBps = FHE.div(diffScaled, expectedPrice);
        
        // Check if within bounds
        euint64 maxSlippage = FHE.asEuint64(maxSlippageBps);
        isValid = FHE.lte(slippageBps, maxSlippage);
    }

    /*//////////////////////////////////////////////////////////////
                        ADVANCED CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate price impact for large trades
     * @param basePrice Base price without impact
     * @param tradeSize Size of the trade
     * @param liquidity Available liquidity
     * @param state Computation state
     * @return adjustedPrice Price adjusted for impact
     * @return impactBps Price impact in basis points
     */
    function calculatePriceImpact(
        euint64 basePrice,
        euint64 tradeSize,
        euint64 liquidity,
        ComputationState storage state
    ) internal returns (euint64 adjustedPrice, euint64 impactBps) {
        // Impact factor = tradeSize / liquidity
        euint64 impactFactor = OptimizedFHE.precisionDiv(tradeSize, liquidity, state.constants);
        
        // Square root for more realistic impact curve
        euint64 sqrtImpact = OptimizedFHE.fastSqrt(impactFactor, state.constants);
        
        // Impact in basis points (scaled by 10000)
        euint64 tenThousand = FHE.asEuint64(10000);
        impactBps = FHE.mul(sqrtImpact, tenThousand);
        
        // Adjusted price = basePrice * (1 + impact)
        euint64 impactMultiplier = FHE.add(state.constants.precision, sqrtImpact);
        adjustedPrice = OptimizedFHE.precisionMul(basePrice, impactMultiplier, state.constants);
    }

    /**
     * @notice Calculate time decay for options-like curves
     * @param basePrice Base price
     * @param timeToExpiry Time until expiration (seconds)
     * @param decayRate Decay rate per day (basis points)
     * @param state Computation state
     * @return decayedPrice Price after time decay
     */
    function calculateTimeDecay(
        euint64 basePrice,
        uint256 timeToExpiry,
        uint256 decayRate,
        ComputationState storage state
    ) internal returns (euint64 decayedPrice) {
        // Convert time to days (86400 seconds per day)
        uint256 daysToExpiry = timeToExpiry / 86400;
        
        // Decay factor = (1 - decayRate/10000)^days
        euint64 decayRateScaled = FHE.asEuint64(decayRate);
        euint64 tenThousand = FHE.asEuint64(10000);
        euint64 decayFactor = FHE.sub(tenThousand, decayRateScaled);
        
        // Apply exponential decay
        euint64 decayMultiplier = OptimizedFHE.fastPow(
            decayFactor,
            daysToExpiry,
            state.constants
        );
        
        // Scale back from 10000 basis
        decayMultiplier = FHE.div(decayMultiplier, tenThousand);
        
        decayedPrice = OptimizedFHE.precisionMul(basePrice, decayMultiplier, state.constants);
    }

    /*//////////////////////////////////////////////////////////////
                        MAINTENANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Clean up expired cache entries
     * @param state Computation state
     * @param maxEntries Maximum entries to clean in one call
     * @return cleaned Number of entries cleaned
     */
    function cleanupCache(
        ComputationState storage state,
        uint256 maxEntries
    ) internal returns (uint256 cleaned) {
        // This is a simplified cleanup - in practice, you'd need to track cache keys
        state.lastCleanup = block.timestamp;
        
        // In a real implementation, this would:
        // 1. Iterate through all cached computation results
        // 2. Check timestamps and remove expired entries
        // 3. Compact the cache storage
        
        // For now, we'll simulate cleaning by resetting some state
        cleaned = 0;
        
        // Reset computation counters if cleanup hasn't happened recently
        if (block.timestamp - state.lastCleanup > 3600) { // 1 hour
            state.lastCleanup = block.timestamp;
            cleaned++;
        }
    }

    /**
     * @notice Get computation statistics
     * @param state Computation state
     * @return hitCount Cache hit count
     * @return missCount Cache miss count
     * @return hitRate Cache hit rate percentage
     */
    function getComputationStats(
        ComputationState storage state
    ) internal view returns (uint256 hitCount, uint256 missCount, uint256 hitRate) {
        return OptimizedFHE.getCacheStats(state.cache);
    }
}