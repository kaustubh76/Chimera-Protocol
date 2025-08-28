# Chimera Protocol - API Reference

## 📖 Complete API Documentation

This document provides comprehensive API reference for all Chimera Protocol contracts, SDK methods, and integration endpoints.

---

## 🔗 Smart Contract APIs

### 1. Custom Curve Hook API

#### Contract: `CustomCurveHook.sol`

##### **setCurveParameters**
```solidity
function setCurveParameters(
    PoolId poolId,
    CurveType curveType,
    bytes[] calldata encryptedCoefficients,
    bytes32 formulaHash,
    uint256 maxLeverage,
    uint256 volatilityFactor
) external
```

**Description**: Sets custom curve parameters for a specific pool.

**Parameters**:
- `poolId`: Unique identifier for the pool
- `curveType`: Type of curve (Linear=0, Exponential=1, Sigmoid=2, Logarithmic=3, Polynomial=4, Custom=5)
- `encryptedCoefficients`: Array of encrypted curve coefficients
- `formulaHash`: Hash of the mathematical formula
- `maxLeverage`: Maximum leverage allowed (in basis points)
- `volatilityFactor`: Volatility adjustment factor

**Events Emitted**:
- `CurveParametersSet(PoolId indexed poolId, CurveType curveType)`

**Access Control**: Only pool creator

##### **calculatePrice**
```solidity
function calculatePrice(
    PoolId poolId,
    uint256 reserves0,
    uint256 reserves1,
    bool zeroForOne
) external view returns (FheUint64)
```

**Description**: Calculates price using the custom curve for a given pool.

**Parameters**:
- `poolId`: Pool identifier
- `reserves0`: Reserve amount of token0
- `reserves1`: Reserve amount of token1
- `zeroForOne`: Direction of trade (true if swapping token0 for token1)

**Returns**: Encrypted price as `FheUint64`

##### **getCurveInfo**
```solidity
function getCurveInfo(PoolId poolId) external view returns (
    CurveType curveType,
    uint256 maxLeverage,
    uint256 volatilityFactor,
    uint256 lastUpdate
)
```

**Description**: Retrieves public information about a curve.

**Returns**:
- `curveType`: The type of curve being used
- `maxLeverage`: Maximum leverage setting
- `volatilityFactor`: Current volatility factor
- `lastUpdate`: Timestamp of last update

---

### 2. Encrypted Alpha Hook API

#### Contract: `EncryptedAlphaHook.sol`

##### **deployStrategy**
```solidity
function deployStrategy(
    PoolId poolId,
    bytes calldata encStrike,
    bytes calldata encLeverage,
    bytes calldata encVolatility,
    bytes calldata encFormula,
    bytes calldata encExpiry
) external
```

**Description**: Deploys a new encrypted trading strategy.

**Parameters**:
- `poolId`: Pool identifier
- `encStrike`: Encrypted strike price
- `encLeverage`: Encrypted leverage factor
- `encVolatility`: Encrypted volatility parameter
- `encFormula`: Encrypted formula hash
- `encExpiry`: Encrypted expiry timestamp

**Events Emitted**:
- `StrategyDeployed(PoolId indexed poolId, address indexed creator)`

##### **updateStrategy**
```solidity
function updateStrategy(
    PoolId poolId,
    bytes calldata newEncStrike,
    bytes calldata newEncLeverage,
    bytes calldata newEncVolatility
) external
```

**Description**: Updates existing strategy parameters.

**Access Control**: Only strategy creator

##### **getStrategyInfo**
```solidity
function getStrategyInfo(PoolId poolId) external view returns (
    address creator,
    bool isActive,
    uint256 lastUpdate,
    uint256 volume
)
```

**Description**: Retrieves public strategy information.

---

### 3. Dark Pool Engine API

#### Contract: `DarkPoolEngine.sol`

##### **submitConfidentialOrder**
```solidity
function submitConfidentialOrder(
    bytes calldata encAmountIn,
    bytes calldata encMinAmountOut,
    bytes calldata encMaxSlippage,
    bytes calldata encOrderType,
    address tokenIn,
    address tokenOut,
    uint256 deadline
) external returns (uint256 orderId)
```

**Description**: Submits an encrypted trading order to the dark pool.

**Parameters**:
- `encAmountIn`: Encrypted input amount
- `encMinAmountOut`: Encrypted minimum output amount
- `encMaxSlippage`: Encrypted maximum slippage tolerance
- `encOrderType`: Encrypted order type (buy=1, sell=2)
- `tokenIn`: Input token address (public)
- `tokenOut`: Output token address (public)
- `deadline`: Order expiration timestamp

**Returns**: Unique order identifier

**Events Emitted**:
- `ConfidentialOrderSubmitted(uint256 indexed orderId, address indexed trader)`

##### **executeBatch**
```solidity
function executeBatch() external
```

**Description**: Executes a batch of pending orders at uniform price.

**Events Emitted**:
- `BatchExecuted(uint256 indexed batchId, uint256 orderCount, uint256 timestamp)`

##### **cancelOrder**
```solidity
function cancelOrder(uint256 orderId) external
```

**Description**: Cancels a pending order.

**Access Control**: Only order creator

##### **getOrderStatus**
```solidity
function getOrderStatus(uint256 orderId) external view returns (
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 deadline,
    uint256 submitTime,
    bool isActive
)
```

**Description**: Retrieves public order information.

---

### 4. Strategy Weaver API

#### Contract: `StrategyWeaver.sol`

##### **createZKPortfolio**
```solidity
function createZKPortfolio(
    bytes[] calldata encryptedWeights,
    address[] calldata assetAddresses,
    bytes calldata encRebalanceStrategy,
    bytes calldata encRebalanceThreshold,
    bytes calldata encRebalanceFrequency,
    bytes calldata encRebalanceConditions
) external returns (uint256 tokenId)
```

**Description**: Creates a new zero-knowledge portfolio.

**Parameters**:
- `encryptedWeights`: Array of encrypted asset allocation weights
- `assetAddresses`: Array of asset contract addresses
- `encRebalanceStrategy`: Encrypted rebalancing strategy
- `encRebalanceThreshold`: Encrypted rebalancing threshold
- `encRebalanceFrequency`: Encrypted rebalancing frequency
- `encRebalanceConditions`: Encrypted rebalancing conditions

**Returns**: Portfolio NFT token ID

**Events Emitted**:
- `PortfolioCreated(uint256 indexed tokenId, address indexed manager, uint256 assetCount)`

##### **depositToPortfolio**
```solidity
function depositToPortfolio(uint256 tokenId, uint256 depositAmount) external
```

**Description**: Deposits funds into a portfolio.

##### **withdrawFromPortfolio**
```solidity
function withdrawFromPortfolio(uint256 tokenId, uint256 sharePercentage) external
```

**Description**: Withdraws a percentage of portfolio holdings.

**Parameters**:
- `tokenId`: Portfolio token ID
- `sharePercentage`: Percentage to withdraw (in basis points, 10000 = 100%)

##### **rebalancePortfolio**
```solidity
function rebalancePortfolio(uint256 tokenId) external
```

**Description**: Triggers portfolio rebalancing according to strategy.

---

## 🔧 SDK APIs

### ChimeraClient Class

#### Constructor
```typescript
constructor(config: ChimeraConfig)

interface ChimeraConfig {
  provider: ethers.providers.Provider;
  signer: ethers.Signer;
  fhenixClient: FhenixClient;
  network: 'local' | 'fhenixHelium' | 'mainnet';
  contracts: {
    encryptedAlphaHook: string;
    darkPoolEngine: string;
    strategyWeaver: string;
    riskManager?: string;
  };
}
```

---

### Strategies Module

#### **deploy**
```typescript
async deploy(params: StrategyDeployParams): Promise<TransactionResponse>

interface StrategyDeployParams {
  curveType: 'linear' | 'exponential' | 'sigmoid' | 'logarithmic' | 'polynomial' | 'custom';
  encryptedParams: {
    strikePrice: Uint8Array;
    leverage: Uint8Array;
    volatility: Uint8Array;
    expiry: Uint8Array;
  };
  tokenA: string;
  tokenB: string;
  fee: number;
  initialPrice: string;
}
```

**Description**: Deploys a new encrypted strategy.

**Example**:
```typescript
const tx = await chimera.strategies.deploy({
  curveType: 'sigmoid',
  encryptedParams: {
    strikePrice: await fhenixClient.encrypt_uint64(3000),
    leverage: await fhenixClient.encrypt_uint64(5),
    volatility: await fhenixClient.encrypt_uint64(25),
    expiry: await fhenixClient.encrypt_uint64(1735689600)
  },
  tokenA: '0x...weth',
  tokenB: '0x...usdc',
  fee: 3000,
  initialPrice: '3000000000000000000000'
});
```

#### **getInfo**
```typescript
async getInfo(poolId: string): Promise<StrategyInfo>

interface StrategyInfo {
  creator: string;
  isActive: boolean;
  lastUpdate: number;
  volume: string;
  curveType: string;
}
```

#### **update**
```typescript
async update(poolId: string, newParams: EncryptedParams): Promise<TransactionResponse>
```

#### **pause**
```typescript
async pause(poolId: string): Promise<TransactionResponse>
```

---

### Dark Pool Module

#### **submitOrder**
```typescript
async submitOrder(params: OrderParams): Promise<TransactionResponse>

interface OrderParams {
  encryptedIntent: {
    amountIn: Uint8Array;
    minAmountOut: Uint8Array;
    maxSlippage: Uint8Array;
    orderType: Uint8Array;
  };
  tokenIn: string;
  tokenOut: string;
  deadline: number;
}
```

**Example**:
```typescript
const tx = await chimera.darkPool.submitOrder({
  encryptedIntent: {
    amountIn: await fhenixClient.encrypt_uint64(1000),
    minAmountOut: await fhenixClient.encrypt_uint64(950),
    maxSlippage: await fhenixClient.encrypt_uint64(50),
    orderType: await fhenixClient.encrypt_bytes32('0x' + '01'.repeat(32))
  },
  tokenIn: '0x...usdc',
  tokenOut: '0x...weth',
  deadline: Math.floor(Date.now() / 1000) + 3600
});
```

#### **getOrderStatus**
```typescript
async getOrderStatus(orderId: string): Promise<OrderStatus>

interface OrderStatus {
  trader: string;
  tokenIn: string;
  tokenOut: string;
  deadline: number;
  submitTime: number;
  isActive: boolean;
}
```

#### **cancelOrder**
```typescript
async cancelOrder(orderId: string): Promise<TransactionResponse>
```

#### **executeBatch**
```typescript
async executeBatch(): Promise<TransactionResponse>
```

---

### Portfolios Module

#### **create**
```typescript
async create(params: PortfolioParams): Promise<TransactionResponse>

interface PortfolioParams {
  encryptedWeights: Uint8Array[];
  assetAddresses: string[];
  encryptedStrategy: Uint8Array;
  encryptedThreshold: Uint8Array;
  encryptedFrequency: Uint8Array;
  name?: string;
}
```

**Example**:
```typescript
const tx = await chimera.portfolios.create({
  encryptedWeights: [
    await fhenixClient.encrypt_uint64(5000), // 50%
    await fhenixClient.encrypt_uint64(3000), // 30%
    await fhenixClient.encrypt_uint64(2000)  // 20%
  ],
  assetAddresses: ['0x...weth', '0x...usdc', '0x...wbtc'],
  encryptedStrategy: await fhenixClient.encrypt_bytes32(strategyHash),
  encryptedThreshold: await fhenixClient.encrypt_uint64(500), // 5%
  encryptedFrequency: await fhenixClient.encrypt_uint64(86400), // daily
  name: 'Balanced Growth Portfolio'
});
```

#### **deposit**
```typescript
async deposit(tokenId: string, amount: string): Promise<TransactionResponse>
```

#### **withdraw**
```typescript
async withdraw(tokenId: string, percentage: number): Promise<TransactionResponse>
```

#### **rebalance**
```typescript
async rebalance(tokenId: string): Promise<TransactionResponse>
```

#### **getInfo**
```typescript
async getInfo(tokenId: string): Promise<PortfolioInfo>

interface PortfolioInfo {
  assetAddresses: string[];
  manager: string;
  creationTime: number;
  lastRebalance: number;
  isActive: boolean;
  currentValue: string;
}
```

---

### Utilities Module

#### **encrypt**
```typescript
// Encrypt values for use in contracts
async encrypt.uint64(value: number): Promise<Uint8Array>
async encrypt.bytes32(value: string): Promise<Uint8Array>
```

#### **decrypt**
```typescript
// Decrypt values (only for values you encrypted)
async decrypt.uint64(encrypted: Uint8Array): Promise<number>
async decrypt.bytes32(encrypted: Uint8Array): Promise<string>
```

#### **estimateGas**
```typescript
async estimateGas(transaction: TransactionRequest): Promise<BigNumber>
```

#### **calculatePrice**
```typescript
async calculatePrice(poolId: string, amountIn: string): Promise<string>
```

---

## 🔍 Event APIs

### Contract Events

#### Custom Curve Hook Events
```solidity
event CurveParametersSet(PoolId indexed poolId, CurveType curveType);
event CurveComputed(PoolId indexed poolId, uint256 timestamp);
event PriceCalculated(PoolId indexed poolId, uint256 newPrice);
```

#### Encrypted Alpha Hook Events
```solidity
event StrategyDeployed(PoolId indexed poolId, address indexed creator);
event StrategyUpdated(PoolId indexed poolId, uint256 timestamp);
event ConfidentialSwap(PoolId indexed poolId, address indexed trader, uint256 timestamp);
```

#### Dark Pool Engine Events
```solidity
event ConfidentialOrderSubmitted(uint256 indexed orderId, address indexed trader);
event BatchExecuted(uint256 indexed batchId, uint256 orderCount, uint256 timestamp);
event OrderFilled(uint256 indexed orderId, address indexed trader);
event OrderCancelled(uint256 indexed orderId, address indexed trader);
```

#### Strategy Weaver Events
```solidity
event PortfolioCreated(uint256 indexed tokenId, address indexed manager, uint256 assetCount);
event PortfolioRebalanced(uint256 indexed tokenId, uint256 timestamp);
event PortfolioDeposit(uint256 indexed tokenId, address indexed depositor, uint256 amount);
event PortfolioWithdrawal(uint256 indexed tokenId, address indexed withdrawer, uint256 amount);
```

### Event Listening with SDK
```typescript
// Listen to strategy deployments
chimera.strategies.on('StrategyDeployed', (poolId, creator, event) => {
  console.log(`New strategy deployed: ${poolId} by ${creator}`);
});

// Listen to portfolio creations
chimera.portfolios.on('PortfolioCreated', (tokenId, manager, assetCount, event) => {
  console.log(`Portfolio ${tokenId} created with ${assetCount} assets`);
});

// Listen to batch executions
chimera.darkPool.on('BatchExecuted', (batchId, orderCount, timestamp, event) => {
  console.log(`Batch ${batchId} executed with ${orderCount} orders`);
});
```

---

## ❌ Error Codes

### Custom Errors

#### Access Control Errors
```solidity
error AccessControl__InsufficientPrivileges(address account, bytes32 role);
error AccessControl__OnlyCreator(address account, address creator);
error AccessControl__OnlyManager(address account, address manager);
```

#### Parameter Validation Errors
```solidity
error CurveParams__InvalidCurveType(uint8 curveType);
error CurveParams__InvalidCoefficients(uint256 length, uint256 expected);
error CurveParams__ExcessiveLeverage(uint256 leverage, uint256 maxLeverage);
error CurveParams__InvalidVolatility(uint256 volatility);
```

#### Order Execution Errors
```solidity
error DarkPool__OrderExpired(uint256 orderId, uint256 deadline);
error DarkPool__OrderNotActive(uint256 orderId);
error DarkPool__InsufficientLiquidity(uint256 required, uint256 available);
error DarkPool__SlippageExceeded(uint256 actual, uint256 maximum);
```

#### Portfolio Management Errors
```solidity
error Portfolio__InvalidWeights(uint256 totalWeight, uint256 expected);
error Portfolio__AssetMismatch(uint256 weightsLength, uint256 assetsLength);
error Portfolio__InsufficientBalance(uint256 requested, uint256 available);
error Portfolio__RebalanceNotReady(uint256 lastRebalance, uint256 frequency);
```

### SDK Error Handling
```typescript
try {
  const tx = await chimera.strategies.deploy(params);
  await tx.wait();
} catch (error) {
  if (error.code === 'INSUFFICIENT_FUNDS') {
    console.error('Insufficient funds for gas');
  } else if (error.message.includes('AccessControl__InsufficientPrivileges')) {
    console.error('Insufficient privileges for this operation');
  } else if (error.message.includes('CurveParams__InvalidCurveType')) {
    console.error('Invalid curve type specified');
  } else {
    console.error('Unexpected error:', error);
  }
}
```

---

## 🔧 Configuration APIs

### Network Configuration
```typescript
interface NetworkConfig {
  chainId: number;
  rpcUrl: string;
  blockExplorer: string;
  contracts: {
    customCurveHook: string;
    encryptedAlphaHook: string;
    darkPoolEngine: string;
    strategyWeaver: string;
    riskManager: string;
  };
}

const networks: Record<string, NetworkConfig> = {
  fhenixHelium: {
    chainId: 8008135,
    rpcUrl: 'https://api.helium.fhenix.zone',
    blockExplorer: 'https://explorer.helium.fhenix.zone',
    contracts: {
      customCurveHook: '0x...',
      encryptedAlphaHook: '0x...',
      darkPoolEngine: '0x...',
      strategyWeaver: '0x...',
      riskManager: '0x...'
    }
  }
};
```

### Gas Configuration
```typescript
interface GasConfig {
  gasLimit: number;
  maxFeePerGas: string;
  maxPriorityFeePerGas: string;
}

// Recommended gas settings
const gasConfig: GasConfig = {
  gasLimit: 5000000,
  maxFeePerGas: ethers.utils.parseUnits('100', 'gwei').toString(),
  maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei').toString()
};
```

---

## 📊 Monitoring APIs

### Real-time Metrics
```typescript
interface MetricsAPI {
  getTVL(): Promise<string>;
  getActiveStrategies(): Promise<number>;
  getTradingVolume(period: '24h' | '7d' | '30d'): Promise<string>;
  getOrderBookDepth(tokenPair: string): Promise<OrderBookDepth>;
}

// Usage
const metrics = new MetricsAPI(config);
const tvl = await metrics.getTVL();
const volume = await metrics.getTradingVolume('24h');
```

### Health Checks
```typescript
interface HealthAPI {
  checkSystemHealth(): Promise<SystemHealth>;
  checkContractStatus(address: string): Promise<ContractStatus>;
  checkNetworkStatus(): Promise<NetworkStatus>;
}

interface SystemHealth {
  status: 'healthy' | 'degraded' | 'critical';
  uptime: number;
  lastBlock: number;
  responseTime: number;
}
```

---

## 🎯 Rate Limits

### API Rate Limits
- **Public endpoints**: 100 requests/minute
- **Authenticated endpoints**: 1000 requests/minute
- **WebSocket connections**: 10 connections/IP
- **Batch requests**: 50 operations/request

### Contract Interaction Limits
- **Order submissions**: 10 orders/block/user
- **Strategy deployments**: 1 strategy/hour/user
- **Portfolio operations**: 5 operations/block/user

---

**📚 For more detailed examples and integration guides, see the [Developer Guide](DEVELOPER_GUIDE.md).**

**🆘 For support, join our [Discord](https://discord.gg/chimera) or email developers@chimera.finance**
