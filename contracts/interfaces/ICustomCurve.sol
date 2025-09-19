// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

/**
 * @title ICustomCurve
 * @notice Interface for custom bonding curve implementations with FHE
 * @dev Core interface defining encrypted curve parameters and operations
 */
interface ICustomCurve {
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Supported curve types for price calculations
    enum CurveType {
        LINEAR,          // P = ax + b
        EXPONENTIAL,     // P = a * e^(bx)
        LOGARITHMIC,     // P = a * ln(bx + c)
        POLYNOMIAL,      // P = ax² + bx + c
        SIGMOID,         // P = L / (1 + e^(-k(x-x₀)))
        CUSTOM          // User-defined formula
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Encrypted curve parameters for confidential strategies
    struct CurveParams {
        CurveType curveType;                // Type of curve being used
        euint64[] encryptedCoefficients; // Encrypted curve parameters [a, b, c, d]
        bytes32 formulaHash;            // Hash of the curve formula
        uint256 maxLeverage;               // Maximum leverage allowed (1e18 = 1x)
        uint256 volatilityFactor;          // Volatility adjustment (basis points)
        uint256 minLiquidity;              // Minimum liquidity requirement
        uint256 maxSlippage;               // Maximum slippage allowed (basis points)
        uint256 timeDecayRate;             // Time decay for options (basis points/day)
        bool isActive;                     // Whether curve is active
        uint256 lastUpdate;                // Last parameter update timestamp
        address strategist;                // Address of strategy creator
    }

    /// @notice Current state of a curve pool
    struct CurveState {
        uint256 lastUpdateTime;            // Last state update timestamp
        uint256 totalLiquidity;            // Total liquidity in pool
        uint256 reserves0;                 // Token0 reserves
        uint256 reserves1;                 // Token1 reserves
        uint256 volume24h;                 // 24-hour trading volume
        uint256 feeAccumulated;            // Accumulated fees
        uint256 priceImpact;               // Current price impact
        bool isActive;                     // State activation status
    }

    /// @notice Encrypted computation cache for gas optimization
    struct ComputationCache {
        mapping(bytes32 => euint64) results;     // Cached computation results
        mapping(bytes32 => uint256) timestamps;    // Result timestamps
        uint256 cacheTimeout;                      // Cache validity period
        uint256 hitCount;                          // Cache hit counter
        uint256 missCount;                         // Cache miss counter
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when curve parameters are updated
    event CurveParametersUpdated(
        PoolId indexed poolId,
        address indexed strategist,
        CurveType curveType,
        uint256 timestamp
    );

    /// @notice Emitted when custom price is calculated
    event CustomPriceCalculated(
        PoolId indexed poolId,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 price,
        uint256 gasUsed
    );

    /// @notice Emitted when curve state is updated
    event CurveStateUpdated(
        PoolId indexed poolId,
        uint256 reserves0,
        uint256 reserves1,
        uint256 totalLiquidity,
        uint256 timestamp
    );

    /// @notice Emitted when computation is cached
    event ComputationCached(
        PoolId indexed poolId,
        bytes32 indexed cacheKey,
        uint256 gasUsed,
        uint256 timestamp
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CurveNotActive(PoolId poolId);
    error InvalidCurveType(CurveType curveType);
    error InsufficientLiquidity(uint256 available, uint256 required);
    error SlippageExceeded(uint256 actual, uint256 maximum);
    error LeverageExceeded(uint256 requested, uint256 maximum);
    error UnauthorizedStrategist(address caller, address strategist);
    error InvalidParameters(string reason);
    error ComputationFailed(string reason);
    error CacheExpired(bytes32 cacheKey);

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize curve parameters for a pool
     * @param poolId The pool identifier
     * @param params Encrypted curve parameters
     * @return success Whether initialization succeeded
     */
    function initializeCurve(
        PoolId poolId,
        CurveParams calldata params
    ) external returns (bool success);

    /**
     * @notice Update curve parameters (only strategist)
     * @param poolId The pool identifier
     * @param newParams New encrypted parameters
     * @return success Whether update succeeded
     */
    function updateCurveParameters(
        PoolId poolId,
        CurveParams calldata newParams
    ) external returns (bool success);

    /**
     * @notice Calculate custom price using encrypted curve
     * @param poolId The pool identifier
     * @param amountIn Input amount for price calculation
     * @param zeroForOne Direction of the swap
     * @return amountOut Calculated output amount
     * @return gasUsed Gas consumed for calculation
     */
    function calculateCustomPrice(
        PoolId poolId,
        uint256 amountIn,
        bool zeroForOne
    ) external returns (uint256 amountOut, uint256 gasUsed);

    /**
     * @notice Get current curve state (view function)
     * @param poolId The pool identifier
     * @return state Current curve state
     */
    function getCurveState(PoolId poolId) external view returns (CurveState memory state);

    /**
     * @notice Get curve parameters (encrypted)
     * @param poolId The pool identifier
     * @return params Encrypted curve parameters
     */
    function getCurveParams(PoolId poolId) external view returns (CurveParams memory params);

    /**
     * @notice Validate slippage protection
     * @param poolId The pool identifier
     * @param expectedPrice Expected price
     * @param actualPrice Actual calculated price
     * @return isValid Whether slippage is within bounds
     */
    function validateSlippage(
        PoolId poolId,
        uint256 expectedPrice,
        uint256 actualPrice
    ) external view returns (bool isValid);

    /**
     * @notice Check if curve is healthy and operational
     * @param poolId The pool identifier
     * @return isHealthy Whether curve is in good state
     * @return healthScore Health score (0-100)
     */
    function checkCurveHealth(
        PoolId poolId
    ) external view returns (bool isHealthy, uint256 healthScore);

    /*//////////////////////////////////////////////////////////////
                            CACHE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get cached computation result
     * @param poolId The pool identifier
     * @param cacheKey Cache key for lookup
     * @return result Cached FHE result
     * @return found Whether result was found and valid
     */
    function getCachedResult(
        PoolId poolId,
        bytes32 cacheKey
    ) external view returns (euint64 result, bool found);

    /**
     * @notice Cache computation result
     * @param poolId The pool identifier
     * @param cacheKey Cache key for storage
     * @param result FHE result to cache
     */
    function setCachedResult(
        PoolId poolId,
        bytes32 cacheKey,
        euint64 result
    ) external;

    /**
     * @notice Clear expired cache entries
     * @param poolId The pool identifier
     * @return cleared Number of entries cleared
     */
    function clearExpiredCache(PoolId poolId) external returns (uint256 cleared);

    /*//////////////////////////////////////////////////////////////
                        STRATEGIST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emergency pause for curve (strategist only)
     * @param poolId The pool identifier
     */
    function emergencyPause(PoolId poolId) external;

    /**
     * @notice Resume paused curve (strategist only)
     * @param poolId The pool identifier
     */
    function resumeCurve(PoolId poolId) external;

    /**
     * @notice Transfer strategist role
     * @param poolId The pool identifier
     * @param newStrategist New strategist address
     */
    function transferStrategist(PoolId poolId, address newStrategist) external;
}
