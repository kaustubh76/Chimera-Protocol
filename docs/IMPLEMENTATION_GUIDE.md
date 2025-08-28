# Chimera Implementation Guide

## 🚀 Complete End-to-End Implementation Flow

This guide provides step-by-step implementation details for building Chimera from scratch.

## 📋 Prerequisites & Setup

### Development Environment
```bash
# 1. Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Install Foundry for smart contract development
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 3. Install Fhenix CLI
npm install -g @fhenixprotocol/fhenix-cli

# 4. Clone Uniswap V4 core
git clone https://github.com/Uniswap/v4-core.git
cd v4-core && npm install
```

### Project Structure Setup
```bash
mkdir chimera-protocol
cd chimera-protocol

# Initialize project structure
mkdir -p {contracts,test,scripts,frontend,docs}
mkdir -p contracts/{hooks,darkpool,weaver,risk,interfaces,libraries}
mkdir -p test/{unit,integration,e2e}
mkdir -p frontend/{src,public,components}

# Initialize package.json
npm init -y
```

## 🔧 Phase 1: Core Smart Contracts

### 1.1 Custom Curve Hook Implementation

The Custom Curve Hook enables pools to use arbitrary mathematical functions for price discovery, moving beyond the standard x*y=k constant product formula.

```solidity
// contracts/hooks/CustomCurveHook.sol
pragma solidity ^0.8.24;

import {BaseHook} from "v4-core/src/BaseHook.sol";
import {ICustomCurve} from "../interfaces/hooks/ICustomCurve.sol";
import {CustomCurveEngine} from "../libraries/curves/CustomCurveEngine.sol";

contract CustomCurveHook is BaseHook, ICustomCurve {
    mapping(PoolId => CurveParams) public poolCurves;
    mapping(PoolId => address) public poolCreators;
    
    function setCurveParameters(
        PoolId poolId,
        CurveType curveType,
        bytes[] calldata encryptedCoefficients,
        bytes32 formulaHash,
        uint256 maxLeverage,
        uint256 volatilityFactor
    ) external override {
        require(poolCreators[poolId] == msg.sender, "Not pool creator");
        // Implementation for custom curve setup
    }
    
    function calculatePrice(
        PoolId poolId,
        uint256 reserves0,
        uint256 reserves1,
        bool zeroForOne
    ) public view override returns (FheUint64) {
        CurveParams storage params = poolCurves[poolId];
        return params.computePrice(reserves0, reserves1, zeroForOne);
    }
}
```

### 1.2 Encrypted Alpha Hook Implementation

```solidity
// contracts/hooks/EncryptedAlphaHook.sol
pragma solidity ^0.8.24;

import {BaseHook} from "v4-core/src/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {FHE, FheUint64, FheBytes32} from "@fhenixprotocol/contracts/FHE.sol";

contract EncryptedAlphaHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // Encrypted strategy parameters per pool
    struct EncryptedStrategy {
        FheUint64 strikePrice;      // Encrypted strike price
        FheUint64 leverageFactor;   // Encrypted leverage multiplier
        FheUint64 volatilityParam;  // Encrypted volatility coefficient
        FheBytes32 formulaHash;     // Encrypted formula identifier
        FheUint64 expiryTimestamp;  // Encrypted expiry time
        address creator;            // Strategy creator
        bool isActive;              // Strategy status
    }

    // Pool storage
    mapping(PoolId => EncryptedStrategy) public strategies;
    mapping(PoolId => uint256) public lastUpdateTime;
    mapping(PoolId => uint256) public tradingVolume;

    // Events
    event StrategyDeployed(PoolId indexed poolId, address indexed creator);
    event ConfidentialSwap(PoolId indexed poolId, address indexed trader, uint256 timestamp);
    event StrategyUpdated(PoolId indexed poolId, uint256 timestamp);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }

    /// @notice Initialize pool with encrypted strategy parameters
    function beforeInitialize(address, PoolKey calldata key, uint160, bytes calldata hookData)
        external
        override
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        
        // Decode encrypted strategy parameters from hookData
        (
            bytes memory encStrike,
            bytes memory encLeverage,
            bytes memory encVolatility,
            bytes memory encFormula,
            bytes memory encExpiry
        ) = abi.decode(hookData, (bytes, bytes, bytes, bytes, bytes));

        // Store encrypted parameters
        strategies[poolId] = EncryptedStrategy({
            strikePrice: FHE.asEuint64(encStrike),
            leverageFactor: FHE.asEuint64(encLeverage),
            volatilityParam: FHE.asEuint64(encVolatility),
            formulaHash: FHE.asEbytes32(encFormula),
            expiryTimestamp: FHE.asEuint64(encExpiry),
            creator: tx.origin,
            isActive: true
        });

        lastUpdateTime[poolId] = block.timestamp;
        
        emit StrategyDeployed(poolId, tx.origin);
        return BaseHook.beforeInitialize.selector;
    }

    /// @notice Execute confidential swap with encrypted price calculation
    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        EncryptedStrategy storage strategy = strategies[poolId];
        
        require(strategy.isActive, "Strategy not active");

        // Perform confidential price calculation
        FheUint64 confidentialPrice = calculateConfidentialPrice(poolId, params);
        
        // Update trading metrics (public)
        tradingVolume[poolId] += uint256(int256(params.amountSpecified));
        lastUpdateTime[poolId] = block.timestamp;

        emit ConfidentialSwap(poolId, tx.origin, block.timestamp);
        
        // Return modified price (decrypted for settlement)
        uint256 finalPrice = FHE.decrypt(confidentialPrice);
        
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, uint24(finalPrice % type(uint24).max));
    }

    /// @notice Calculate price using encrypted parameters
    function calculateConfidentialPrice(PoolId poolId, IPoolManager.SwapParams calldata params) 
        internal 
        view 
        returns (FheUint64) 
    {
        EncryptedStrategy storage strategy = strategies[poolId];
        
        // Get current reserves (public data)
        uint256 reserve0 = 1000000; // Mock reserve - replace with actual
        uint256 reserve1 = 2000000; // Mock reserve - replace with actual
        
        // Confidential computation using encrypted parameters
        FheUint64 basePrice = FHE.asEuint64(reserve1 * 1e18 / reserve0);
        
        // Apply encrypted leverage
        FheUint64 leveragedPrice = FHE.mul(basePrice, strategy.leverageFactor);
        
        // Apply volatility adjustment based on trading volume
        FheUint64 volatilityAdjustment = calculateVolatilityAdjustment(poolId);
        FheUint64 adjustedPrice = FHE.add(leveragedPrice, volatilityAdjustment);
        
        // Apply time decay if strategy has expiry
        FheUint64 timeDecayFactor = calculateTimeDecay(poolId);
        FheUint64 finalPrice = FHE.mul(adjustedPrice, timeDecayFactor);
        
        return finalPrice;
    }

    /// @notice Calculate volatility adjustment based on recent trading
    function calculateVolatilityAdjustment(PoolId poolId) internal view returns (FheUint64) {
        EncryptedStrategy storage strategy = strategies[poolId];
        
        // Calculate realized volatility from trading volume
        uint256 timeDelta = block.timestamp - lastUpdateTime[poolId];
        uint256 volumeVelocity = timeDelta > 0 ? tradingVolume[poolId] / timeDelta : 0;
        
        // Apply encrypted volatility parameter
        FheUint64 realizedVol = FHE.asEuint64(volumeVelocity);
        FheUint64 volatilityAdjustment = FHE.mul(realizedVol, strategy.volatilityParam);
        
        return volatilityAdjustment;
    }

    /// @notice Calculate time decay for options-like products
    function calculateTimeDecay(PoolId poolId) internal view returns (FheUint64) {
        EncryptedStrategy storage strategy = strategies[poolId];
        
        // Current timestamp as encrypted value
        FheUint64 currentTime = FHE.asEuint64(block.timestamp);
        
        // Calculate time to expiry confidentially
        FheUint64 timeToExpiry = FHE.sub(strategy.expiryTimestamp, currentTime);
        
        // Simple linear decay model (can be made more sophisticated)
        FheUint64 maxTime = FHE.asEuint64(365 days);
        FheUint64 decayFactor = FHE.div(timeToExpiry, maxTime);
        
        return decayFactor;
    }

    /// @notice Update strategy parameters (only creator)
    function updateStrategy(
        PoolId poolId,
        bytes calldata newEncStrike,
        bytes calldata newEncLeverage,
        bytes calldata newEncVolatility
    ) external {
        require(strategies[poolId].creator == msg.sender, "Only creator can update");
        
        EncryptedStrategy storage strategy = strategies[poolId];
        strategy.strikePrice = FHE.asEuint64(newEncStrike);
        strategy.leverageFactor = FHE.asEuint64(newEncLeverage);
        strategy.volatilityParam = FHE.asEuint64(newEncVolatility);
        
        lastUpdateTime[poolId] = block.timestamp;
        emit StrategyUpdated(poolId, block.timestamp);
    }

    /// @notice Emergency pause strategy
    function pauseStrategy(PoolId poolId) external {
        require(strategies[poolId].creator == msg.sender, "Only creator can pause");
        strategies[poolId].isActive = false;
    }

    /// @notice Get strategy status (public info only)
    function getStrategyInfo(PoolId poolId) external view returns (
        address creator,
        bool isActive,
        uint256 lastUpdate,
        uint256 volume
    ) {
        EncryptedStrategy storage strategy = strategies[poolId];
        return (
            strategy.creator,
            strategy.isActive,
            lastUpdateTime[poolId],
            tradingVolume[poolId]
        );
    }
}
```

### 1.2 Dark Pool Engine Implementation

```solidity
// contracts/darkpool/DarkPoolEngine.sol
pragma solidity ^0.8.24;

import {FHE, FheUint64, FheBytes32, FheBool} from "@fhenixprotocol/contracts/FHE.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DarkPoolEngine is ReentrancyGuard {
    
    // Encrypted order structure
    struct ConfidentialOrder {
        FheUint64 amountIn;         // Encrypted input amount
        FheUint64 minAmountOut;     // Encrypted minimum output
        FheUint64 maxSlippage;      // Encrypted slippage tolerance
        FheBytes32 orderType;       // Encrypted order type
        address trader;             // Public trader address
        address tokenIn;            // Public input token
        address tokenOut;           // Public output token
        uint256 deadline;           // Public deadline
        uint256 submitTime;         // Public submission time
        bool isActive;              // Order status
    }

    // Batch execution structure
    struct BatchExecution {
        uint256 batchId;
        uint256 totalOrders;
        uint256 executionTime;
        FheUint64 uniformPrice;     // Encrypted uniform execution price
        bool isExecuted;
    }

    // State variables
    mapping(uint256 => ConfidentialOrder) public orders;
    mapping(uint256 => BatchExecution) public batches;
    mapping(uint256 => uint256[]) public batchOrders; // batchId => orderIds
    
    uint256 public nextOrderId;
    uint256 public nextBatchId;
    uint256 public batchInterval = 300; // 5 minutes
    uint256 public lastBatchTime;
    uint256 public maxBatchSize = 100;

    // Events
    event ConfidentialOrderSubmitted(uint256 indexed orderId, address indexed trader);
    event BatchExecuted(uint256 indexed batchId, uint256 orderCount, uint256 timestamp);
    event OrderFilled(uint256 indexed orderId, address indexed trader);

    constructor() {
        lastBatchTime = block.timestamp;
    }

    /// @notice Submit encrypted trading intent to dark pool
    function submitConfidentialOrder(
        bytes calldata encAmountIn,
        bytes calldata encMinAmountOut,
        bytes calldata encMaxSlippage,
        bytes calldata encOrderType,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) external nonReentrant returns (uint256 orderId) {
        require(deadline > block.timestamp, "Order expired");
        require(tokenIn != tokenOut, "Invalid token pair");

        orderId = nextOrderId++;

        // Store encrypted order
        orders[orderId] = ConfidentialOrder({
            amountIn: FHE.asEuint64(encAmountIn),
            minAmountOut: FHE.asEuint64(encMinAmountOut),
            maxSlippage: FHE.asEuint64(encMaxSlippage),
            orderType: FHE.asEbytes32(encOrderType),
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            deadline: deadline,
            submitTime: block.timestamp,
            isActive: true
        });

        // Transfer tokens to contract (escrow)
        uint256 amountIn = FHE.decrypt(FHE.asEuint64(encAmountIn));
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        emit ConfidentialOrderSubmitted(orderId, msg.sender);

        // Trigger batch execution if conditions met
        if (shouldExecuteBatch()) {
            executeBatch();
        }

        return orderId;
    }

    /// @notice Check if batch should be executed
    function shouldExecuteBatch() public view returns (bool) {
        return (
            block.timestamp >= lastBatchTime + batchInterval ||
            getCurrentBatchSize() >= maxBatchSize
        );
    }

    /// @notice Get current pending orders count
    function getCurrentBatchSize() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive && orders[i].deadline > block.timestamp) {
                count++;
            }
        }
        return count;
    }

    /// @notice Execute batch of orders with confidential price discovery
    function executeBatch() public nonReentrant {
        require(shouldExecuteBatch(), "Batch execution not ready");

        uint256 batchId = nextBatchId++;
        uint256[] memory currentBatchOrders = new uint256[](maxBatchSize);
        uint256 orderCount = 0;

        // Collect active orders for batch
        for (uint256 i = 0; i < nextOrderId && orderCount < maxBatchSize; i++) {
            if (orders[i].isActive && orders[i].deadline > block.timestamp) {
                currentBatchOrders[orderCount] = i;
                orderCount++;
            }
        }

        require(orderCount > 0, "No orders to execute");

        // Perform confidential price discovery
        FheUint64 uniformPrice = calculateUniformPrice(currentBatchOrders, orderCount);

        // Create batch record
        batches[batchId] = BatchExecution({
            batchId: batchId,
            totalOrders: orderCount,
            executionTime: block.timestamp,
            uniformPrice: uniformPrice,
            isExecuted: true
        });

        // Store batch orders
        for (uint256 i = 0; i < orderCount; i++) {
            batchOrders[batchId].push(currentBatchOrders[i]);
        }

        // Execute orders at uniform price
        executeOrdersAtUniformPrice(currentBatchOrders, orderCount, uniformPrice);

        lastBatchTime = block.timestamp;
        emit BatchExecuted(batchId, orderCount, block.timestamp);
    }

    /// @notice Calculate uniform execution price confidentially
    function calculateUniformPrice(uint256[] memory orderIds, uint256 count) 
        internal 
        view 
        returns (FheUint64) 
    {
        if (count == 0) return FHE.asEuint64(0);

        // Initialize weighted sum variables
        FheUint64 totalWeightedPrice = FHE.asEuint64(0);
        FheUint64 totalWeight = FHE.asEuint64(0);

        // Calculate weighted average price confidentially
        for (uint256 i = 0; i < count; i++) {
            ConfidentialOrder storage order = orders[orderIds[i]];
            
            // Weight by order amount
            FheUint64 weight = order.amountIn;
            
            // Calculate implied price from min output
            FheUint64 impliedPrice = FHE.div(order.minAmountOut, order.amountIn);
            
            // Add to weighted sum
            FheUint64 weightedPrice = FHE.mul(impliedPrice, weight);
            totalWeightedPrice = FHE.add(totalWeightedPrice, weightedPrice);
            totalWeight = FHE.add(totalWeight, weight);
        }

        // Return weighted average
        return FHE.div(totalWeightedPrice, totalWeight);
    }

    /// @notice Execute all orders at the uniform price
    function executeOrdersAtUniformPrice(
        uint256[] memory orderIds, 
        uint256 count, 
        FheUint64 uniformPrice
    ) internal {
        for (uint256 i = 0; i < count; i++) {
            uint256 orderId = orderIds[i];
            ConfidentialOrder storage order = orders[orderId];
            
            if (!order.isActive) continue;

            // Calculate output amount at uniform price
            FheUint64 outputAmount = FHE.mul(order.amountIn, uniformPrice);
            
            // Check if order can be filled (confidential comparison)
            FheBool canFill = FHE.gte(outputAmount, order.minAmountOut);
            
            // Decrypt the boolean for execution decision
            if (FHE.decrypt(canFill)) {
                // Execute the order
                uint256 finalOutputAmount = FHE.decrypt(outputAmount);
                
                // Transfer tokens to trader
                IERC20(order.tokenOut).transfer(order.trader, finalOutputAmount);
                
                // Mark order as filled
                order.isActive = false;
                
                emit OrderFilled(orderId, order.trader);
            }
        }
    }

    /// @notice Cancel order (only by trader)
    function cancelOrder(uint256 orderId) external {
        ConfidentialOrder storage order = orders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.isActive, "Order not active");

        // Refund tokens
        uint256 refundAmount = FHE.decrypt(order.amountIn);
        IERC20(order.tokenIn).transfer(msg.sender, refundAmount);

        order.isActive = false;
    }

    /// @notice Get order status (public info only)
    function getOrderStatus(uint256 orderId) external view returns (
        address trader,
        address tokenIn,
        address tokenOut,
        uint256 deadline,
        uint256 submitTime,
        bool isActive
    ) {
        ConfidentialOrder storage order = orders[orderId];
        return (
            order.trader,
            order.tokenIn,
            order.tokenOut,
            order.deadline,
            order.submitTime,
            order.isActive
        );
    }

    /// @notice Update batch parameters (admin only)
    function updateBatchParameters(uint256 newInterval, uint256 newMaxSize) external {
        // Add admin access control here
        batchInterval = newInterval;
        maxBatchSize = newMaxSize;
    }
}
```

### 1.3 ZK-Portfolio Weaver Implementation

```solidity
// contracts/weaver/StrategyWeaver.sol
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {FHE, FheUint64, FheBytes32} from "@fhenixprotocol/contracts/FHE.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyWeaver is ERC721, ReentrancyGuard {
    
    // ZK-Portfolio structure
    struct ZKPortfolio {
        uint256 tokenId;                    // Public portfolio identifier
        FheUint64[] assetWeights;          // Encrypted allocation weights
        address[] assetAddresses;          // Public asset addresses
        FheBytes32 rebalanceStrategy;      // Encrypted rebalancing logic
        FheUint64 totalValue;              // Encrypted total value
        FheBytes32 performanceMetrics;     // Encrypted performance data
        address manager;                   // Portfolio manager
        uint256 creationTime;              // Creation timestamp
        uint256 lastRebalance;             // Last rebalance time
        bool isActive;                     // Portfolio status
    }

    // Rebalancing parameters
    struct RebalanceParams {
        FheUint64 threshold;               // Encrypted rebalance threshold
        FheUint64 frequency;               // Encrypted rebalance frequency
        FheBytes32 conditions;             // Encrypted trigger conditions
    }

    // State variables
    mapping(uint256 => ZKPortfolio) public portfolios;
    mapping(uint256 => RebalanceParams) public rebalanceParams;
    mapping(uint256 => mapping(address => uint256)) public assetBalances; // tokenId => asset => balance
    
    uint256 public nextTokenId;
    uint256 public managementFee = 200; // 2% annual
    uint256 public performanceFee = 2000; // 20%

    // Events
    event PortfolioCreated(uint256 indexed tokenId, address indexed manager, uint256 assetCount);
    event PortfolioRebalanced(uint256 indexed tokenId, uint256 timestamp);
    event PortfolioDeposit(uint256 indexed tokenId, address indexed depositor, uint256 amount);
    event PortfolioWithdrawal(uint256 indexed tokenId, address indexed withdrawer, uint256 amount);

    constructor() ERC721("Chimera ZK-Portfolio", "CZKP") {}

    /// @notice Create a new ZK-Portfolio with encrypted composition
    function createZKPortfolio(
        bytes[] calldata encryptedWeights,
        address[] calldata assetAddresses,
        bytes calldata encRebalanceStrategy,
        bytes calldata encRebalanceThreshold,
        bytes calldata encRebalanceFrequency,
        bytes calldata encRebalanceConditions
    ) external returns (uint256 tokenId) {
        require(encryptedWeights.length == assetAddresses.length, "Mismatched arrays");
        require(encryptedWeights.length > 0, "Empty portfolio");
        require(encryptedWeights.length <= 20, "Too many assets");

        tokenId = nextTokenId++;

        // Convert encrypted weights
        FheUint64[] memory weights = new FheUint64[](encryptedWeights.length);
        for (uint256 i = 0; i < encryptedWeights.length; i++) {
            weights[i] = FHE.asEuint64(encryptedWeights[i]);
        }

        // Create portfolio
        portfolios[tokenId] = ZKPortfolio({
            tokenId: tokenId,
            assetWeights: weights,
            assetAddresses: assetAddresses,
            rebalanceStrategy: FHE.asEbytes32(encRebalanceStrategy),
            totalValue: FHE.asEuint64(0),
            performanceMetrics: FHE.asEbytes32(""),
            manager: msg.sender,
            creationTime: block.timestamp,
            lastRebalance: block.timestamp,
            isActive: true
        });

        // Set rebalancing parameters
        rebalanceParams[tokenId] = RebalanceParams({
            threshold: FHE.asEuint64(encRebalanceThreshold),
            frequency: FHE.asEuint64(encRebalanceFrequency),
            conditions: FHE.asEbytes32(encRebalanceConditions)
        });

        // Mint NFT to manager
        _mint(msg.sender, tokenId);

        emit PortfolioCreated(tokenId, msg.sender, assetAddresses.length);
        return tokenId;
    }

    /// @notice Deposit funds and receive proportional portfolio shares
    function depositToPortfolio(uint256 tokenId, uint256 depositAmount) 
        external 
        nonReentrant 
    {
        require(_exists(tokenId), "Portfolio does not exist");
        require(portfolios[tokenId].isActive, "Portfolio not active");
        require(depositAmount > 0, "Invalid deposit amount");

        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        // Calculate current portfolio value
        uint256 currentValue = calculatePortfolioValue(tokenId);
        
        // Determine asset allocation based on encrypted weights
        allocateDeposit(tokenId, depositAmount);
        
        // Update total value (encrypted)
        FheUint64 encDepositAmount = FHE.asEuint64(depositAmount);
        portfolio.totalValue = FHE.add(portfolio.totalValue, encDepositAmount);

        emit PortfolioDeposit(tokenId, msg.sender, depositAmount);
    }

    /// @notice Allocate deposit across portfolio assets using encrypted weights
    function allocateDeposit(uint256 tokenId, uint256 depositAmount) internal {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        // For each asset in the portfolio
        for (uint256 i = 0; i < portfolio.assetAddresses.length; i++) {
            address asset = portfolio.assetAddresses[i];
            
            // Calculate allocation using encrypted weight
            FheUint64 encDepositAmount = FHE.asEuint64(depositAmount);
            FheUint64 allocation = FHE.mul(encDepositAmount, portfolio.assetWeights[i]);
            
            // Decrypt for actual token transfer
            uint256 assetAllocation = FHE.decrypt(allocation);
            
            if (assetAllocation > 0) {
                // Transfer tokens to portfolio
                IERC20(asset).transferFrom(msg.sender, address(this), assetAllocation);
                
                // Update balance tracking
                assetBalances[tokenId][asset] += assetAllocation;
            }
        }
    }

    /// @notice Withdraw proportional share from portfolio
    function withdrawFromPortfolio(uint256 tokenId, uint256 sharePercentage) 
        external 
        nonReentrant 
    {
        require(ownerOf(tokenId) == msg.sender, "Not portfolio owner");
        require(sharePercentage > 0 && sharePercentage <= 10000, "Invalid percentage"); // 10000 = 100%

        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        // Calculate withdrawal amounts for each asset
        for (uint256 i = 0; i < portfolio.assetAddresses.length; i++) {
            address asset = portfolio.assetAddresses[i];
            uint256 assetBalance = assetBalances[tokenId][asset];
            
            if (assetBalance > 0) {
                uint256 withdrawAmount = (assetBalance * sharePercentage) / 10000;
                
                // Transfer asset to owner
                IERC20(asset).transfer(msg.sender, withdrawAmount);
                
                // Update balance
                assetBalances[tokenId][asset] -= withdrawAmount;
            }
        }

        // Update total value
        FheUint64 withdrawalRatio = FHE.asEuint64(sharePercentage);
        FheUint64 totalWithdrawal = FHE.mul(portfolio.totalValue, withdrawalRatio);
        portfolio.totalValue = FHE.sub(portfolio.totalValue, totalWithdrawal);

        emit PortfolioWithdrawal(tokenId, msg.sender, sharePercentage);
    }

    /// @notice Perform confidential rebalancing
    function rebalancePortfolio(uint256 tokenId) external {
        require(_exists(tokenId), "Portfolio does not exist");
        
        ZKPortfolio storage portfolio = portfolios[tokenId];
        require(portfolio.isActive, "Portfolio not active");
        
        // Check if rebalancing is needed (confidential check)
        if (shouldRebalance(tokenId)) {
            executeRebalance(tokenId);
            portfolio.lastRebalance = block.timestamp;
            
            emit PortfolioRebalanced(tokenId, block.timestamp);
        }
    }

    /// @notice Check if portfolio needs rebalancing (confidential)
    function shouldRebalance(uint256 tokenId) internal view returns (bool) {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        RebalanceParams storage params = rebalanceParams[tokenId];
        
        // Time-based check
        uint256 timeSinceRebalance = block.timestamp - portfolio.lastRebalance;
        FheUint64 timeThreshold = params.frequency;
        
        // Decrypt time comparison for simplicity (could be kept encrypted)
        uint256 frequencyThreshold = FHE.decrypt(timeThreshold);
        
        return timeSinceRebalance >= frequencyThreshold;
    }

    /// @notice Execute portfolio rebalancing with encrypted logic
    function executeRebalance(uint256 tokenId) internal {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        // Calculate current asset values
        uint256 totalValue = calculatePortfolioValue(tokenId);
        
        if (totalValue == 0) return;
        
        // Rebalance each asset to target weight
        for (uint256 i = 0; i < portfolio.assetAddresses.length; i++) {
            address asset = portfolio.assetAddresses[i];
            
            // Calculate target allocation using encrypted weight
            FheUint64 encTotalValue = FHE.asEuint64(totalValue);
            FheUint64 targetAllocation = FHE.mul(encTotalValue, portfolio.assetWeights[i]);
            
            uint256 targetAmount = FHE.decrypt(targetAllocation);
            uint256 currentAmount = assetBalances[tokenId][asset];
            
            // Adjust allocation if needed
            if (targetAmount > currentAmount) {
                // Need to buy more of this asset
                uint256 buyAmount = targetAmount - currentAmount;
                // Implement buying logic here
                assetBalances[tokenId][asset] = targetAmount;
            } else if (targetAmount < currentAmount) {
                // Need to sell some of this asset
                uint256 sellAmount = currentAmount - targetAmount;
                // Implement selling logic here
                assetBalances[tokenId][asset] = targetAmount;
            }
        }
    }

    /// @notice Calculate total portfolio value (public calculation)
    function calculatePortfolioValue(uint256 tokenId) public view returns (uint256) {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < portfolio.assetAddresses.length; i++) {
            address asset = portfolio.assetAddresses[i];
            uint256 balance = assetBalances[tokenId][asset];
            
            // Get asset price (mock - implement proper price oracle)
            uint256 assetPrice = getAssetPrice(asset);
            totalValue += balance * assetPrice / 1e18;
        }
        
        return totalValue;
    }

    /// @notice Get asset price (mock implementation)
    function getAssetPrice(address asset) internal pure returns (uint256) {
        // Mock prices - implement proper oracle integration
        return 1e18; // $1 for all assets
    }

    /// @notice Update portfolio strategy (manager only)
    function updateStrategy(
        uint256 tokenId,
        bytes calldata newEncRebalanceStrategy,
        bytes calldata newEncThreshold,
        bytes calldata newEncFrequency
    ) external {
        require(portfolios[tokenId].manager == msg.sender, "Not portfolio manager");
        
        ZKPortfolio storage portfolio = portfolios[tokenId];
        RebalanceParams storage params = rebalanceParams[tokenId];
        
        portfolio.rebalanceStrategy = FHE.asEbytes32(newEncRebalanceStrategy);
        params.threshold = FHE.asEuint64(newEncThreshold);
        params.frequency = FHE.asEuint64(newEncFrequency);
    }

    /// @notice Get portfolio public information
    function getPortfolioInfo(uint256 tokenId) external view returns (
        address[] memory assetAddresses,
        address manager,
        uint256 creationTime,
        uint256 lastRebalance,
        bool isActive,
        uint256 currentValue
    ) {
        require(_exists(tokenId), "Portfolio does not exist");
        
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        return (
            portfolio.assetAddresses,
            portfolio.manager,
            portfolio.creationTime,
            portfolio.lastRebalance,
            portfolio.isActive,
            calculatePortfolioValue(tokenId)
        );
    }

    /// @notice Pause/unpause portfolio (manager only)
    function setPortfolioStatus(uint256 tokenId, bool status) external {
        require(portfolios[tokenId].manager == msg.sender, "Not portfolio manager");
        portfolios[tokenId].isActive = status;
    }
}
```

This implementation guide provides the core smart contracts with detailed code examples. Let me continue with the remaining components:

<function_calls>
<invoke name="todo_write">
<parameter name="merge">true
