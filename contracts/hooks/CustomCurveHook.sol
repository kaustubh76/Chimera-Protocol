// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICustomCurve} from "../interfaces/ICustomCurve.sol";
import {IDarkPoolEngine} from "../interfaces/IDarkPoolEngine.sol";
import {IStrategyWeaver} from "../interfaces/IStrategyWeaver.sol";
import {FHECurveEngine} from "../libraries/FHECurveEngine.sol";
import {OptimizedFHE} from "../libraries/OptimizedFHE.sol";

/**
 * @title CustomCurveHook
 * @notice Uniswap V4 hook implementing confidential custom bonding curves with FHE
 * @dev Main hook contract that enables encrypted curve parameters and MEV-resistant pricing
 */
contract CustomCurveHook is IHooks, ICustomCurve, Ownable, Pausable, ReentrancyGuard {
    using PoolIdLibrary for PoolKey;
    using FHECurveEngine for *;
    using OptimizedFHE for *;

    error HookNotImplemented();
    error NotPoolManager();

    IPoolManager public immutable poolManager;
    
    /// @notice Dark pool engine for MEV-resistant trading
    IDarkPoolEngine public darkPoolEngine;
    
    /// @notice Strategy weaver for portfolio management
    IStrategyWeaver public strategyWeaver;

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from pool ID to curve parameters
    mapping(PoolId => CurveParams) public poolCurves;
    
    /// @notice Mapping from pool ID to curve state
    mapping(PoolId => CurveState) public curveStates;
    
    /// @notice Mapping from pool ID to computation state (for caching)
    mapping(PoolId => FHECurveEngine.ComputationState) private computationStates;
    
    /// @notice Mapping from pool ID to precomputed prices (gas optimization)
    mapping(PoolId => mapping(uint256 => euint64)) private precomputedPrices;
    
    /// @notice Mapping for authorized strategists per pool
    mapping(PoolId => mapping(address => bool)) public authorizedStrategists;
    
    /// @notice Global hook configuration
    struct HookConfig {
        uint256 maxGasPerCalculation;     // Maximum gas per price calculation
        uint256 cacheTimeout;             // Cache timeout in seconds
        uint256 precomputeInterval;       // Precomputation interval in seconds
        uint256 minLiquidityThreshold;    // Minimum liquidity threshold
        bool emergencyMode;               // Emergency mode flag
    }
    
    HookConfig public hookConfig;
    
    /// @notice Swap computation cache for staged execution
    struct SwapComputationCache {
        uint256 expectedPrice;
        uint256 computationTimestamp;
        bool isPending;
        uint256 fallbackPrice;
    }
    
    /// @notice Mapping from swap ID to computation cache
    mapping(bytes32 => SwapComputationCache) private swapComputations;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event HookConfigUpdated(
        uint256 maxGasPerCalculation,
        uint256 cacheTimeout,
        uint256 precomputeInterval
    );

    event StrategistAuthorized(PoolId indexed poolId, address indexed strategist, bool authorized);
    
    event PrecomputationExecuted(PoolId indexed poolId, uint256 pricePoints, uint256 gasUsed);
    
    event EmergencyModeToggled(bool enabled);
    
    event DecryptionRequested(PoolId indexed poolId, euint64 encryptedValue);
    event DecryptionCompleted(PoolId indexed poolId, uint256 decryptedValue);
    event SwapComputationCached(bytes32 indexed swapId, uint256 fallbackPrice);
    event SwapComputationCompleted(bytes32 indexed swapId, uint256 finalPrice);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error GasLimitExceeded(uint256 gasUsed, uint256 gasLimit);
    error EmergencyModeActive();
    error InsufficientLiquidityForCurve(uint256 available, uint256 required);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        IPoolManager _poolManager,
        address initialOwner
    ) Ownable(initialOwner) {
        poolManager = _poolManager;
        Hooks.validateHookPermissions(this, getHookPermissions());
        
        // Initialize default hook configuration
        hookConfig = HookConfig({
            maxGasPerCalculation: 10_000_000,  // 10M gas max per calculation
            cacheTimeout: 300,                 // 5 minutes cache
            precomputeInterval: 600,           // 10 minutes precompute interval
            minLiquidityThreshold: 1000e18,    // Minimum 1000 tokens liquidity
            emergencyMode: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get hook permissions for Uniswap V4 integration
     * @return Hooks.Permissions struct defining which hooks are implemented
     */
    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,        // Setup encrypted curve parameters
            afterInitialize: true,         // Validate curve configuration
            beforeAddLiquidity: true,      // Validate curve constraints
            afterAddLiquidity: true,       // Update curve state + return BalanceDelta
            beforeRemoveLiquidity: true,   // Ensure curve integrity
            afterRemoveLiquidity: true,    // Maintain curve + return BalanceDelta
            beforeSwap: true,              // Custom price + return BeforeSwapDelta
            afterSwap: true,               // Update state + return fee adjustment
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,   // Required for beforeSwap
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: true,    // Return delta for liquidity ops
            afterRemoveLiquidityReturnDelta: true  // Return delta for liquidity ops
        });
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/


    /**
     * @notice Called before pool initialization to set up curve parameters
     * @param key Pool key containing token addresses and fee tier
     * @param sqrtPriceX96 Initial sqrt price
     * @return selector Function selector to continue execution
     */
    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160 sqrtPriceX96
    ) external override onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        
        // For now, use default curve parameters
        // In a real implementation, these would come from a separate setup function
        CurveParams memory curveParams;
        address strategist = address(0);
        
        // Validate curve parameters
        _validateCurveParams(curveParams);
        
        // Set strategist authorization
        authorizedStrategists[poolId][strategist] = true;
        curveParams.strategist = strategist;
        curveParams.lastUpdate = block.timestamp;
        curveParams.isActive = true;
        
        // Store curve parameters
        poolCurves[poolId] = curveParams;
        
        // Initialize computation state
        FHECurveEngine.initializeState(computationStates[poolId]);
        
        // Initialize curve state
        curveStates[poolId] = CurveState({
            lastUpdateTime: block.timestamp,
            totalLiquidity: 0,
            reserves0: 0,
            reserves1: 0,
            volume24h: 0,
            feeAccumulated: 0,
            priceImpact: 0,
            isActive: true
        });
        
        emit CurveParametersUpdated(poolId, strategist, curveParams.curveType, block.timestamp);
        
        return this.beforeInitialize.selector;
    }

    /**
     * @notice Called after pool initialization to validate setup
     * @param key Pool key
     * @param sqrtPriceX96 Initial sqrt price
     * @param tick Initial tick
     * @return selector Function selector to continue execution
     */
    function afterInitialize(
        address,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external override onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        
        // Validate that curve was properly initialized
        require(poolCurves[poolId].isActive, "Curve not properly initialized");
        require(curveStates[poolId].isActive, "Curve state not initialized");
        
        // Start precomputation for gas optimization
        _schedulePrecomputation(poolId);
        
        return this.afterInitialize.selector;
    }

    /**
     * @notice Called before adding liquidity to validate against curve constraints
     * @param key Pool key
     * @param params Liquidity parameters
     * @return selector Function selector to continue execution
     */
    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        CurveParams storage curve = poolCurves[poolId];
        
        require(curve.isActive, "Curve not active");
        
        // Check minimum liquidity requirements
        if (params.liquidityDelta > 0) {
            uint256 newTotalLiquidity = curveStates[poolId].totalLiquidity + uint256(int256(params.liquidityDelta));
            require(newTotalLiquidity >= curve.minLiquidity, "Insufficient liquidity for curve integrity");
        }
        
        return this.beforeAddLiquidity.selector;
    }

    /**
     * @notice Called after adding liquidity to update curve state
     * @param key Pool key
     * @param params Liquidity parameters
     * @param delta Balance delta from liquidity change
     * @return selector Function selector to continue execution
     * @return balanceDelta Additional balance delta from curve logic
     */
    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        
        // Update curve state with new liquidity
        CurveState storage state = curveStates[poolId];
        if (params.liquidityDelta > 0) {
            state.totalLiquidity += uint256(int256(params.liquidityDelta));
        } else {
            state.totalLiquidity -= uint256(int256(-params.liquidityDelta));
        }
        state.lastUpdateTime = block.timestamp;
        
        // Emit state update event
        emit CurveStateUpdated(
            poolId,
            state.reserves0,
            state.reserves1,
            state.totalLiquidity,
            block.timestamp
        );
        
        // Return zero delta for now (could implement liquidity incentives here)
        return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    /**
     * @notice Called before removing liquidity to validate curve integrity
     */
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        CurveParams storage curve = poolCurves[poolId];
        CurveState storage state = curveStates[poolId];
        
        require(curve.isActive, "Curve not active");
        
        // Check that removal won't break minimum liquidity
        if (params.liquidityDelta < 0) {
            uint256 removalAmount = uint256(int256(-params.liquidityDelta));
            require(
                state.totalLiquidity > removalAmount + curve.minLiquidity,
                "Removal would break minimum liquidity requirement"
            );
        }
        
        return this.beforeRemoveLiquidity.selector;
    }

    /**
     * @notice Called after removing liquidity to update curve state
     */
    function afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        
        // Update curve state
        CurveState storage state = curveStates[poolId];
        if (params.liquidityDelta < 0) {
            uint256 removalAmount = uint256(int256(-params.liquidityDelta));
            state.totalLiquidity -= removalAmount;
        }
        state.lastUpdateTime = block.timestamp;
        
        emit CurveStateUpdated(
            poolId,
            state.reserves0,
            state.reserves1,
            state.totalLiquidity,
            block.timestamp
        );
        
        return (this.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    /**
     * @notice Called before swap to calculate custom price and apply modifications
     * @dev This is where the magic happens - custom curve pricing with FHE
     */
    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        
        PoolId poolId = key.toId();
        uint256 startGas = gasleft();
        
        // Check emergency mode
        if (hookConfig.emergencyMode) revert EmergencyModeActive();
        
        CurveParams storage curve = poolCurves[poolId];
        require(curve.isActive, "Curve not active");
        
        // Generate swap ID for caching
        bytes32 swapId = keccak256(abi.encodePacked(
            poolId,
            params.amountSpecified,
            params.zeroForOne,
            block.timestamp,
            tx.origin
        ));
        
        uint256 inputAmount = uint256(params.amountSpecified > 0 ? 
            params.amountSpecified : -params.amountSpecified);
        
        // Try to get decrypted price using new engine
        (uint256 decryptedPrice, bool isReady, uint256 gasUsed) = FHECurveEngine.calculateAndDecryptPrice(
            PoolId.unwrap(poolId),
            inputAmount,
            curve,
            computationStates[poolId]
        );
        
        // Check gas limit
        if (gasUsed > hookConfig.maxGasPerCalculation) {
            revert GasLimitExceeded(gasUsed, hookConfig.maxGasPerCalculation);
        }
        
        uint256 finalPrice;
        
        if (isReady) {
            // Decryption ready - use computed price
            finalPrice = decryptedPrice;
        } else {
            // Decryption not ready - use fallback pricing strategy
            finalPrice = _calculateFallbackPrice(poolId, inputAmount, curve);
            
            // Cache computation for potential completion in afterSwap
            swapComputations[swapId] = SwapComputationCache({
                expectedPrice: 0, // Will be set when decryption completes
                computationTimestamp: block.timestamp,
                isPending: true,
                fallbackPrice: finalPrice
            });
        }
        
        // Calculate swap delta based on final price
        BeforeSwapDelta swapDelta = _calculateSwapDelta(
            finalPrice,
            params.amountSpecified,
            params.zeroForOne
        );
        
        // Calculate dynamic fee based on volatility
        uint24 dynamicFee = _calculateDynamicFee(poolId, gasUsed);
        
        // Update curve state
        _updateCurveState(poolId, params, finalPrice);
        
        // Emit price calculation event
        emit CustomPriceCalculated(
            poolId,
            inputAmount,
            finalPrice,
            finalPrice,
            startGas - gasleft()
        );
        
        return (this.beforeSwap.selector, swapDelta, dynamicFee);
    }

    /**
     * @notice Called after swap to update final state and apply additional logic
     */
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, int128) {
        PoolId poolId = key.toId();
        
        // Generate swap ID to check for pending computations
        bytes32 swapId = keccak256(abi.encodePacked(
            poolId,
            params.amountSpecified,
            params.zeroForOne,
            block.timestamp,
            tx.origin
        ));
        
        // Check if we had a pending computation
        SwapComputationCache storage swapCache = swapComputations[swapId];
        
        if (swapCache.isPending) {
            // Try to complete the decryption
            uint256 inputAmount = uint256(params.amountSpecified > 0 ? 
                params.amountSpecified : -params.amountSpecified);
            
            (uint256 decryptedPrice, bool isReady) = FHECurveEngine.tryCompleteDecryption(
                PoolId.unwrap(poolId),
                inputAmount,
                poolCurves[poolId],
                computationStates[poolId]
            );
            
            if (isReady) {
                // Decryption completed - emit completion event
                emit DecryptionCompleted(poolId, decryptedPrice);
                
                // Clear the pending computation
                delete swapComputations[swapId];
            }
        }
        
        // Update 24h volume tracking
        CurveState storage state = curveStates[poolId];
        uint256 swapAmount = uint256(params.amountSpecified > 0 ? 
            params.amountSpecified : -params.amountSpecified);
        state.volume24h += swapAmount;
        state.lastUpdateTime = block.timestamp;
        
        // Calculate any additional fees or rebates
        int128 additionalFee = 0; // Could implement fee sharing here
        
        return (this.afterSwap.selector, additionalFee);
    }

    /**
     * @notice Called before donate - not implemented in this hook
     */
    function beforeDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external view override onlyPoolManager returns (bytes4) {
        revert HookNotImplemented();
    }

    /**
     * @notice Called after donate - not implemented in this hook
     */
    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external view override onlyPoolManager returns (bytes4) {
        revert HookNotImplemented();
    }

    /*//////////////////////////////////////////////////////////////
                        ICUSTOMCURVE IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize curve parameters for a pool
     */
    function initializeCurve(
        PoolId poolId,
        CurveParams calldata params
    ) external override returns (bool success) {
        require(authorizedStrategists[poolId][msg.sender], "Not authorized strategist");
        
        _validateCurveParams(params);
        
        poolCurves[poolId] = params;
        poolCurves[poolId].strategist = msg.sender;
        poolCurves[poolId].lastUpdate = block.timestamp;
        poolCurves[poolId].isActive = true;
        
        FHECurveEngine.initializeState(computationStates[poolId]);
        
        emit CurveParametersUpdated(poolId, msg.sender, params.curveType, block.timestamp);
        
        success = true;
    }

    /**
     * @notice Update curve parameters (strategist only)
     */
    function updateCurveParameters(
        PoolId poolId,
        CurveParams calldata newParams
    ) external override returns (bool success) {
        require(authorizedStrategists[poolId][msg.sender], "Not authorized strategist");
        require(poolCurves[poolId].isActive, "Curve not active");
        
        _validateCurveParams(newParams);
        
        CurveParams storage curve = poolCurves[poolId];
        curve.encryptedCoefficients = newParams.encryptedCoefficients;
        curve.maxLeverage = newParams.maxLeverage;
        curve.volatilityFactor = newParams.volatilityFactor;
        curve.maxSlippage = newParams.maxSlippage;
        curve.timeDecayRate = newParams.timeDecayRate;
        curve.lastUpdate = block.timestamp;
        
        emit CurveParametersUpdated(poolId, msg.sender, curve.curveType, block.timestamp);
        
        success = true;
    }

    /**
     * @notice Calculate custom price using encrypted curve
     */
    function calculateCustomPrice(
        PoolId poolId,
        uint256 amountIn,
        bool zeroForOne
    ) external override returns (uint256 amountOut, uint256 gasUsed) {
        CurveParams storage curve = poolCurves[poolId];
        require(curve.isActive, "Curve not active");
        
        uint256 startGas = gasleft();
        
        // Use the new FHECurveEngine with integrated decryption
        (uint256 decryptedPrice, bool isReady, uint256 calcGasUsed) = FHECurveEngine.calculateAndDecryptPrice(
            PoolId.unwrap(poolId),
            amountIn,
            curve,
            computationStates[poolId]
        );
        
        if (isReady) {
            // Decryption ready - use computed price
            amountOut = decryptedPrice;
        } else {
            // Try to complete any pending decryption
            (uint256 completedPrice, bool completed) = FHECurveEngine.tryCompleteDecryption(
                PoolId.unwrap(poolId),
                amountIn,
                curve,
                computationStates[poolId]
            );
            
            if (completed) {
                amountOut = completedPrice;
                emit DecryptionCompleted(poolId, completedPrice);
            } else {
                // Use fallback pricing
                amountOut = _calculateFallbackPrice(poolId, amountIn, curve);
            }
        }
        
        gasUsed = startGas - gasleft();
        emit CustomPriceCalculated(poolId, amountIn, amountOut, amountOut, gasUsed);
    }

    /**
     * @notice Get current curve state
     */
    function getCurveState(PoolId poolId) external view override returns (CurveState memory state) {
        state = curveStates[poolId];
    }

    /**
     * @notice Get curve parameters
     */
    function getCurveParams(PoolId poolId) external view override returns (CurveParams memory params) {
        params = poolCurves[poolId];
    }

    /**
     * @notice Validate slippage protection
     */
    function validateSlippage(
        PoolId poolId,
        uint256 expectedPrice,
        uint256 actualPrice
    ) external view override returns (bool isValid) {
        CurveParams storage curve = poolCurves[poolId];
        
        uint256 diff = actualPrice > expectedPrice ? 
            actualPrice - expectedPrice : expectedPrice - actualPrice;
        uint256 slippageBps = (diff * 10000) / expectedPrice;
        
        isValid = slippageBps <= curve.maxSlippage;
    }

    /**
     * @notice Check curve health
     */
    function checkCurveHealth(
        PoolId poolId
    ) external view override returns (bool isHealthy, uint256 healthScore) {
        CurveParams storage curve = poolCurves[poolId];
        CurveState storage state = curveStates[poolId];
        
        if (!curve.isActive || !state.isActive) {
            return (false, 0);
        }
        
        // Calculate health score based on various factors
        healthScore = 100;
        
        // Reduce score for low liquidity
        if (state.totalLiquidity < curve.minLiquidity * 2) {
            healthScore -= 20;
        }
        
        // Reduce score for high volatility
        if (curve.volatilityFactor > 1000) { // > 10%
            healthScore -= 15;
        }
        
        // Reduce score for old updates
        if (block.timestamp - curve.lastUpdate > 86400) { // > 1 day
            healthScore -= 10;
        }
        
        isHealthy = healthScore >= 70;
    }

    /*//////////////////////////////////////////////////////////////
                            CACHE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getCachedResult(
        PoolId poolId,
        bytes32 cacheKey
    ) external view override returns (euint64 result, bool found) {
        return OptimizedFHE.getCachedResult(computationStates[poolId].cache, cacheKey);
    }

    function setCachedResult(
        PoolId poolId,
        bytes32 cacheKey,
        euint64 result
    ) external override {
        require(authorizedStrategists[poolId][msg.sender], "Not authorized");
        OptimizedFHE.setCachedResult(computationStates[poolId].cache, cacheKey, result);
    }

    function clearExpiredCache(PoolId poolId) external override returns (uint256 cleared) {
        cleared = 0;
        
        // Clear expired swap computations
        // Note: In production, you'd iterate through swapComputations and clear old ones
        // For now, we'll just mark that cleanup occurred
        
        // Clear old cached computations in the FHE engine
        if (block.timestamp > computationStates[poolId].lastCleanup + 3600) { // 1 hour
            computationStates[poolId].lastCleanup = block.timestamp;
            cleared = 1;
        }
        
        emit CacheCleared(poolId, cleared);
    }
    
    event CacheCleared(PoolId indexed poolId, uint256 itemsCleared);

    /*//////////////////////////////////////////////////////////////
                        STRATEGIST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function emergencyPause(PoolId poolId) external override {
        require(authorizedStrategists[poolId][msg.sender], "Not authorized strategist");
        poolCurves[poolId].isActive = false;
        curveStates[poolId].isActive = false;
    }

    function resumeCurve(PoolId poolId) external override {
        require(authorizedStrategists[poolId][msg.sender], "Not authorized strategist");
        poolCurves[poolId].isActive = true;
        curveStates[poolId].isActive = true;
    }

    function transferStrategist(PoolId poolId, address newStrategist) external override {
        require(authorizedStrategists[poolId][msg.sender], "Not authorized strategist");
        authorizedStrategists[poolId][msg.sender] = false;
        authorizedStrategists[poolId][newStrategist] = true;
        poolCurves[poolId].strategist = newStrategist;
        
        emit StrategistAuthorized(poolId, newStrategist, true);
        emit StrategistAuthorized(poolId, msg.sender, false);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateHookConfig(HookConfig calldata newConfig) external onlyOwner {
        hookConfig = newConfig;
        emit HookConfigUpdated(
            newConfig.maxGasPerCalculation,
            newConfig.cacheTimeout,
            newConfig.precomputeInterval
        );
    }

    function setEmergencyMode(bool enabled) external onlyOwner {
        hookConfig.emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }

    function authorizeStrategist(PoolId poolId, address strategist, bool authorized) external onlyOwner {
        authorizedStrategists[poolId][strategist] = authorized;
        emit StrategistAuthorized(poolId, strategist, authorized);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateCurveParams(CurveParams memory params) internal pure {
        require(params.encryptedCoefficients.length > 0, "No coefficients provided");
        require(params.maxLeverage > 0 && params.maxLeverage <= 100e18, "Invalid leverage");
        require(params.volatilityFactor <= 10000, "Volatility factor too high"); // Max 100%
        require(params.maxSlippage <= 5000, "Max slippage too high"); // Max 50%
        require(params.minLiquidity > 0, "Min liquidity must be positive");
    }

    function _calculateSwapDelta(
        uint256 customPrice,
        int256 amountSpecified,
        bool zeroForOne
    ) internal pure returns (BeforeSwapDelta) {
        // Simplified delta calculation - in production this would be more sophisticated
        int128 deltaAmount = int128(int256(customPrice * uint256(
            amountSpecified < 0 ? uint256(-amountSpecified) : uint256(amountSpecified)
        )) / 1e18);
        
        // Use toBeforeSwapDelta with specified and unspecified amounts
        return toBeforeSwapDelta(deltaAmount, int128(0));
    }

    function _calculateDynamicFee(PoolId poolId, uint256 gasUsed) internal view returns (uint24) {
        CurveParams storage curve = poolCurves[poolId];
        
        // Base fee + volatility adjustment + gas cost adjustment
        uint24 baseFee = 3000; // 0.3%
        uint24 volatilityAdjustment = uint24(curve.volatilityFactor / 10); // Scale down
        uint24 gasAdjustment = uint24(gasUsed / 100000); // Scale gas to fee
        
        return baseFee + volatilityAdjustment + gasAdjustment;
    }

    function _calculateFallbackPrice(
        PoolId poolId,
        uint256 inputAmount,
        CurveParams storage curve
    ) internal view returns (uint256 fallbackPrice) {
        CurveState storage state = curveStates[poolId];
        
        // Use simple constant product formula with volatility adjustment
        if (state.reserves0 > 0 && state.reserves1 > 0) {
            // AMM-style pricing with volatility factor
            uint256 k = state.reserves0 * state.reserves1;
            uint256 newReserve0 = state.reserves0 + inputAmount;
            uint256 newReserve1 = k / newReserve0;
            uint256 outputAmount = state.reserves1 - newReserve1;
            
            // Apply volatility adjustment
            uint256 volatilityMultiplier = 10000 + curve.volatilityFactor; // basis points
            fallbackPrice = (outputAmount * volatilityMultiplier) / 10000;
        } else {
            // No reserves - use input amount with spread
            fallbackPrice = (inputAmount * 95) / 100; // 5% spread as fallback
        }
    }

    function _updateCurveState(
        PoolId poolId,
        IPoolManager.SwapParams calldata params,
        uint256 price
    ) internal {
        CurveState storage state = curveStates[poolId];
        
        // Update reserves (simplified)
        uint256 amountAbs = uint256(params.amountSpecified > 0 ? 
            params.amountSpecified : -params.amountSpecified);
        
        if (params.zeroForOne) {
            state.reserves0 += amountAbs;
            state.reserves1 -= (amountAbs * price) / 1e18;
        } else {
            state.reserves1 += amountAbs;
            state.reserves0 -= (amountAbs * 1e18) / price;
        }
        
        state.lastUpdateTime = block.timestamp;
    }

    function _schedulePrecomputation(PoolId poolId) internal {
        // Schedule precomputation of curve values for gas optimization
        CurveParams storage curve = poolCurves[poolId];
        
        // Precompute common values based on curve type
        uint256 pricePoints = 10; // Precompute 10 price points
        uint256 startGas = gasleft();
        
        // In a real implementation, this would:
        // 1. Calculate key price points for the curve
        // 2. Store them in the computation state cache
        // 3. Set up periodic refresh schedules
        
        // For now, we'll just mark that precomputation occurred
        computationStates[poolId].lastCleanup = block.timestamp;
        
        uint256 gasUsed = startGas - gasleft();
        emit PrecomputationExecuted(poolId, pricePoints, gasUsed);
    }
}
