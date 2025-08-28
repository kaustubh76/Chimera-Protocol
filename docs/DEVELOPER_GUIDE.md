# Chimera Developer Guide

## 🚀 Quick Start for Developers

Welcome to Chimera! This guide will get you building confidential DeFi applications in minutes.

## 📚 Table of Contents

1. [Environment Setup](#environment-setup)
2. [SDK Installation](#sdk-installation)
3. [Basic Usage](#basic-usage)
4. [API Reference](#api-reference)
5. [Code Examples](#code-examples)
6. [Advanced Features](#advanced-features)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## 🛠️ Environment Setup

### Prerequisites
```bash
# Node.js 18+ and npm
node --version  # >= 18.0.0
npm --version   # >= 8.0.0

# Git
git --version

# Optional: VS Code with Solidity extension
code --version
```

### Quick Setup
```bash
# 1. Clone the starter template
git clone https://github.com/ChimeraProtocol/chimera-starter.git
cd chimera-starter

# 2. Install dependencies
npm install

# 3. Set up environment
cp .env.example .env
# Edit .env with your configuration

# 4. Test connection
npm run test:connection
```

## 📦 SDK Installation

### Core SDK
```bash
# Install Chimera SDK
npm install @chimera-protocol/sdk

# Install Fhenix client
npm install @fhenixprotocol/fhenix.js

# Install Uniswap V4 periphery
npm install @uniswap/v4-periphery
```

### TypeScript Setup
```bash
# Install TypeScript dependencies
npm install -D typescript @types/node

# Create tsconfig.json
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020"],
    "module": "commonjs",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "skipLibCheck": true,
    "declaration": true,
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF
```

## 🎯 Basic Usage

### Initialize Chimera Client

```typescript
// src/setup.ts
import { ChimeraClient } from '@chimera-protocol/sdk';
import { FhenixClient } from '@fhenixprotocol/fhenix.js';
import { ethers } from 'ethers';

// Setup provider and signer
const provider = new ethers.providers.JsonRpcProvider(process.env.FHENIX_RPC_URL);
const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// Initialize Fhenix client
const fhenixClient = new FhenixClient({ provider });

// Initialize Chimera client
const chimera = new ChimeraClient({
  provider,
  signer,
  fhenixClient,
  network: 'fhenixHelium', // or 'mainnet'
  contracts: {
    encryptedAlphaHook: process.env.ENCRYPTED_ALPHA_HOOK_ADDRESS,
    darkPoolEngine: process.env.DARK_POOL_ENGINE_ADDRESS,
    strategyWeaver: process.env.STRATEGY_WEAVER_ADDRESS
  }
});

export { chimera, fhenixClient };
```

### Create Your First Encrypted Strategy

```typescript
// src/examples/create-strategy.ts
import { chimera, fhenixClient } from '../setup';

async function createEncryptedStrategy() {
  console.log('🔐 Creating encrypted trading strategy...');
  
  try {
    // Define strategy parameters (these will be encrypted)
    const strategyParams = {
      strikePrice: 3000,      // $3000 strike price
      leverage: 5,            // 5x leverage
      volatility: 25,         // 25% volatility parameter
      expiry: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60) // 30 days
    };
    
    // Encrypt the parameters
    const encryptedParams = {
      strikePrice: await fhenixClient.encrypt_uint64(strategyParams.strikePrice),
      leverage: await fhenixClient.encrypt_uint64(strategyParams.leverage),
      volatility: await fhenixClient.encrypt_uint64(strategyParams.volatility),
      expiry: await fhenixClient.encrypt_uint64(strategyParams.expiry)
    };
    
    // Deploy the strategy
    const tx = await chimera.strategies.deploy({
      curveType: 'sigmoid',           // Curve type for options
      encryptedParams,
      tokenA: '0x...tokenA',          // Base token
      tokenB: '0x...tokenB',          // Quote token
      fee: 3000,                      // 0.3% fee tier
      initialPrice: '1000000000000000000' // Initial price
    });
    
    console.log('📄 Transaction hash:', tx.hash);
    
    // Wait for confirmation
    const receipt = await tx.wait();
    console.log('✅ Strategy deployed successfully!');
    console.log('🏊 Pool ID:', receipt.events[0].args.poolId);
    
    return receipt.events[0].args.poolId;
    
  } catch (error) {
    console.error('❌ Strategy deployment failed:', error);
    throw error;
  }
}

// Run the example
createEncryptedStrategy()
  .then(poolId => console.log('🎉 Strategy created with Pool ID:', poolId))
  .catch(console.error);
```

### Execute a Dark Pool Trade

```typescript
// src/examples/dark-pool-trade.ts
import { chimera, fhenixClient } from '../setup';

async function executeDarkPoolTrade() {
  console.log('🌑 Executing dark pool trade...');
  
  try {
    // Define trade parameters
    const tradeParams = {
      amountIn: 1000,        // 1000 tokens
      minAmountOut: 900,     // Minimum 900 tokens out
      slippage: 50,          // 0.5% max slippage
      deadline: Math.floor(Date.now() / 1000) + 3600 // 1 hour
    };
    
    // Encrypt trade intent
    const encryptedIntent = {
      amountIn: await fhenixClient.encrypt_uint64(tradeParams.amountIn),
      minAmountOut: await fhenixClient.encrypt_uint64(tradeParams.minAmountOut),
      maxSlippage: await fhenixClient.encrypt_uint64(tradeParams.slippage),
      orderType: await fhenixClient.encrypt_bytes32('0x' + '01'.repeat(32)) // Buy order
    };
    
    // Submit to dark pool
    const tx = await chimera.darkPool.submitOrder({
      encryptedIntent,
      tokenIn: '0x...tokenIn',
      tokenOut: '0x...tokenOut',
      deadline: tradeParams.deadline
    });
    
    console.log('📄 Order submitted:', tx.hash);
    
    // Wait for batch execution
    const receipt = await tx.wait();
    const orderId = receipt.events[0].args.orderId;
    
    console.log('✅ Order submitted with ID:', orderId);
    
    // Monitor order status
    const orderStatus = await chimera.darkPool.getOrderStatus(orderId);
    console.log('📊 Order status:', orderStatus);
    
    return orderId;
    
  } catch (error) {
    console.error('❌ Dark pool trade failed:', error);
    throw error;
  }
}

// Run the example
executeDarkPoolTrade()
  .then(orderId => console.log('🎉 Dark pool order created:', orderId))
  .catch(console.error);
```

### Create a ZK-Portfolio

```typescript
// src/examples/zk-portfolio.ts
import { chimera, fhenixClient } from '../setup';

async function createZKPortfolio() {
  console.log('🧩 Creating ZK-Portfolio...');
  
  try {
    // Define portfolio composition (weights sum to 10000 = 100%)
    const portfolioConfig = {
      assets: [
        '0x...weth',     // WETH
        '0x...usdc',     // USDC  
        '0x...wbtc'      // WBTC
      ],
      weights: [
        5000,            // 50% WETH
        3000,            // 30% USDC
        2000             // 20% WBTC
      ],
      rebalanceThreshold: 500,  // 5% threshold
      rebalanceFrequency: 86400 // Daily rebalancing
    };
    
    // Encrypt portfolio weights and strategy
    const encryptedWeights = await Promise.all(
      portfolioConfig.weights.map(weight => 
        fhenixClient.encrypt_uint64(weight)
      )
    );
    
    const encryptedStrategy = await fhenixClient.encrypt_bytes32(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes('balanced_growth_v1'))
    );
    
    const encryptedThreshold = await fhenixClient.encrypt_uint64(
      portfolioConfig.rebalanceThreshold
    );
    
    const encryptedFrequency = await fhenixClient.encrypt_uint64(
      portfolioConfig.rebalanceFrequency
    );
    
    // Create the portfolio
    const tx = await chimera.portfolios.create({
      encryptedWeights,
      assetAddresses: portfolioConfig.assets,
      encryptedStrategy,
      encryptedThreshold,
      encryptedFrequency,
      name: 'My Balanced Growth Portfolio'
    });
    
    console.log('📄 Transaction hash:', tx.hash);
    
    // Wait for confirmation
    const receipt = await tx.wait();
    const tokenId = receipt.events[0].args.tokenId;
    
    console.log('✅ ZK-Portfolio created!');
    console.log('🎫 Portfolio Token ID:', tokenId);
    
    // Get portfolio info
    const portfolioInfo = await chimera.portfolios.getInfo(tokenId);
    console.log('📊 Portfolio Info:', portfolioInfo);
    
    return tokenId;
    
  } catch (error) {
    console.error('❌ Portfolio creation failed:', error);
    throw error;
  }
}

// Run the example
createZKPortfolio()
  .then(tokenId => console.log('🎉 Portfolio created with Token ID:', tokenId))
  .catch(console.error);
```

## 📖 API Reference

### ChimeraClient

#### Constructor
```typescript
new ChimeraClient(config: ChimeraConfig)
```

#### Configuration
```typescript
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

### Strategies Module

#### Deploy Strategy
```typescript
chimera.strategies.deploy(params: StrategyDeployParams): Promise<TransactionResponse>
```

```typescript
interface StrategyDeployParams {
  curveType: 'linear' | 'exponential' | 'sigmoid' | 'logarithmic';
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

#### Get Strategy Info
```typescript
chimera.strategies.getInfo(poolId: string): Promise<StrategyInfo>
```

```typescript
interface StrategyInfo {
  creator: string;
  isActive: boolean;
  lastUpdate: number;
  volume: string;
  curveType: string;
}
```

#### Update Strategy
```typescript
chimera.strategies.update(poolId: string, newParams: EncryptedParams): Promise<TransactionResponse>
```

#### Pause Strategy
```typescript
chimera.strategies.pause(poolId: string): Promise<TransactionResponse>
```

### Dark Pool Module

#### Submit Order
```typescript
chimera.darkPool.submitOrder(params: OrderParams): Promise<TransactionResponse>
```

```typescript
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

#### Get Order Status
```typescript
chimera.darkPool.getOrderStatus(orderId: string): Promise<OrderStatus>
```

```typescript
interface OrderStatus {
  trader: string;
  tokenIn: string;
  tokenOut: string;
  deadline: number;
  submitTime: number;
  isActive: boolean;
}
```

#### Cancel Order
```typescript
chimera.darkPool.cancelOrder(orderId: string): Promise<TransactionResponse>
```

#### Execute Batch
```typescript
chimera.darkPool.executeBatch(): Promise<TransactionResponse>
```

### Portfolios Module

#### Create Portfolio
```typescript
chimera.portfolios.create(params: PortfolioParams): Promise<TransactionResponse>
```

```typescript
interface PortfolioParams {
  encryptedWeights: Uint8Array[];
  assetAddresses: string[];
  encryptedStrategy: Uint8Array;
  encryptedThreshold: Uint8Array;
  encryptedFrequency: Uint8Array;
  name?: string;
}
```

#### Deposit to Portfolio
```typescript
chimera.portfolios.deposit(tokenId: string, amount: string): Promise<TransactionResponse>
```

#### Withdraw from Portfolio
```typescript
chimera.portfolios.withdraw(tokenId: string, percentage: number): Promise<TransactionResponse>
```

#### Rebalance Portfolio
```typescript
chimera.portfolios.rebalance(tokenId: string): Promise<TransactionResponse>
```

#### Get Portfolio Info
```typescript
chimera.portfolios.getInfo(tokenId: string): Promise<PortfolioInfo>
```

```typescript
interface PortfolioInfo {
  assetAddresses: string[];
  manager: string;
  creationTime: number;
  lastRebalance: number;
  isActive: boolean;
  currentValue: string;
}
```

### Utilities Module

#### Encrypt Values
```typescript
chimera.utils.encrypt.uint64(value: number): Promise<Uint8Array>
chimera.utils.encrypt.bytes32(value: string): Promise<Uint8Array>
```

#### Decrypt Values
```typescript
chimera.utils.decrypt.uint64(encrypted: Uint8Array): Promise<number>
chimera.utils.decrypt.bytes32(encrypted: Uint8Array): Promise<string>
```

#### Calculate Gas
```typescript
chimera.utils.estimateGas(transaction: TransactionRequest): Promise<BigNumber>
```

#### Price Calculation
```typescript
chimera.utils.calculatePrice(poolId: string, amountIn: string): Promise<string>
```

## 💡 Code Examples

### Advanced Strategy with Custom Curve

```typescript
// src/examples/custom-curve-strategy.ts
import { chimera, fhenixClient } from '../setup';
import { ethers } from 'ethers';

async function createCustomCurveStrategy() {
  // Define a custom sigmoid curve for a complex option strategy
  const customParams = {
    strikePrice: 2500,
    leverage: 3,
    volatility: 30,
    upperBound: 5000,
    lowerBound: 1000,
    timeDecay: 100, // days
    riskFactor: 15
  };
  
  // Create encoded formula for custom curve
  const formulaCode = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ['string', 'uint256[]'],
      ['custom_sigmoid_with_bounds', [
        customParams.upperBound,
        customParams.lowerBound,
        customParams.timeDecay,
        customParams.riskFactor
      ]]
    )
  );
  
  const encryptedParams = {
    strikePrice: await fhenixClient.encrypt_uint64(customParams.strikePrice),
    leverage: await fhenixClient.encrypt_uint64(customParams.leverage),
    volatility: await fhenixClient.encrypt_uint64(customParams.volatility),
    formulaCode: await fhenixClient.encrypt_bytes32(formulaCode),
    expiry: await fhenixClient.encrypt_uint64(
      Math.floor(Date.now() / 1000) + (customParams.timeDecay * 24 * 60 * 60)
    )
  };
  
  const tx = await chimera.strategies.deploy({
    curveType: 'custom',
    encryptedParams,
    tokenA: '0x...weth',
    tokenB: '0x...usdc',
    fee: 3000,
    initialPrice: '2500000000000000000000' // $2500
  });
  
  const receipt = await tx.wait();
  return receipt.events[0].args.poolId;
}
```

### Batch Dark Pool Operations

```typescript
// src/examples/batch-operations.ts
import { chimera, fhenixClient } from '../setup';

async function submitBatchOrders() {
  const orders = [
    { amountIn: 1000, minOut: 950, slippage: 50 },
    { amountIn: 2000, minOut: 1900, slippage: 50 },
    { amountIn: 1500, minOut: 1425, slippage: 50 }
  ];
  
  const orderPromises = orders.map(async (order) => {
    const encryptedIntent = {
      amountIn: await fhenixClient.encrypt_uint64(order.amountIn),
      minAmountOut: await fhenixClient.encrypt_uint64(order.minOut),
      maxSlippage: await fhenixClient.encrypt_uint64(order.slippage),
      orderType: await fhenixClient.encrypt_bytes32('0x' + '01'.repeat(32))
    };
    
    return chimera.darkPool.submitOrder({
      encryptedIntent,
      tokenIn: '0x...usdc',
      tokenOut: '0x...weth',
      deadline: Math.floor(Date.now() / 1000) + 3600
    });
  });
  
  const txs = await Promise.all(orderPromises);
  console.log('✅ Batch orders submitted:', txs.map(tx => tx.hash));
  
  // Wait for all confirmations
  const receipts = await Promise.all(txs.map(tx => tx.wait()));
  const orderIds = receipts.map(receipt => receipt.events[0].args.orderId);
  
  return orderIds;
}
```

### Dynamic Portfolio Rebalancing

```typescript
// src/examples/dynamic-rebalancing.ts
import { chimera, fhenixClient } from '../setup';

class DynamicPortfolioManager {
  constructor(private tokenId: string) {}
  
  async monitorAndRebalance() {
    // Set up event listener for market changes
    setInterval(async () => {
      const shouldRebalance = await this.checkRebalanceNeeded();
      if (shouldRebalance) {
        await this.executeRebalance();
      }
    }, 60000); // Check every minute
  }
  
  private async checkRebalanceNeeded(): Promise<boolean> {
    const portfolioInfo = await chimera.portfolios.getInfo(this.tokenId);
    
    // Get current asset prices and calculate drift
    const currentWeights = await this.calculateCurrentWeights();
    const targetWeights = await this.getTargetWeights();
    
    // Check if any weight has drifted beyond threshold
    for (let i = 0; i < currentWeights.length; i++) {
      const drift = Math.abs(currentWeights[i] - targetWeights[i]);
      if (drift > 500) { // 5% drift threshold
        return true;
      }
    }
    
    return false;
  }
  
  private async executeRebalance() {
    console.log('🔄 Executing portfolio rebalance...');
    
    const tx = await chimera.portfolios.rebalance(this.tokenId);
    const receipt = await tx.wait();
    
    console.log('✅ Portfolio rebalanced:', receipt.transactionHash);
  }
  
  private async calculateCurrentWeights(): Promise<number[]> {
    // Implementation to calculate current weights
    return [5000, 3000, 2000]; // Mock weights
  }
  
  private async getTargetWeights(): Promise<number[]> {
    // Implementation to get encrypted target weights
    return [5000, 3000, 2000]; // Mock weights
  }
}

// Usage
const manager = new DynamicPortfolioManager('1');
manager.monitorAndRebalance();
```

## 🛡️ Best Practices

### Security Guidelines

1. **Encrypt Sensitive Data**
```typescript
// ✅ Good - Encrypt sensitive parameters
const encryptedStrike = await fhenixClient.encrypt_uint64(strikePrice);

// ❌ Bad - Exposing sensitive data
const strategy = { strikePrice: 3000 }; // Visible on-chain
```

2. **Validate Inputs**
```typescript
// ✅ Good - Input validation
function validateStrategyParams(params: StrategyParams) {
  if (params.leverage > 100) throw new Error('Leverage too high');
  if (params.strikePrice <= 0) throw new Error('Invalid strike price');
  if (params.volatility > 10000) throw new Error('Volatility out of range');
}
```

3. **Handle Errors Gracefully**
```typescript
// ✅ Good - Proper error handling
try {
  const tx = await chimera.strategies.deploy(params);
  await tx.wait();
} catch (error) {
  if (error.code === 'INSUFFICIENT_FUNDS') {
    console.error('Insufficient funds for gas');
  } else if (error.message.includes('revert')) {
    console.error('Transaction reverted:', error.reason);
  } else {
    console.error('Unexpected error:', error);
  }
}
```

### Performance Optimization

1. **Batch Operations**
```typescript
// ✅ Good - Batch multiple operations
const encryptPromises = values.map(v => fhenixClient.encrypt_uint64(v));
const encryptedValues = await Promise.all(encryptPromises);

// ❌ Bad - Sequential encryption
const encryptedValues = [];
for (const value of values) {
  encryptedValues.push(await fhenixClient.encrypt_uint64(value));
}
```

2. **Cache Frequently Used Data**
```typescript
class ChimeraCache {
  private cache = new Map<string, any>();
  
  async getStrategyInfo(poolId: string) {
    const cacheKey = `strategy_${poolId}`;
    
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      if (Date.now() - cached.timestamp < 60000) { // 1 minute cache
        return cached.data;
      }
    }
    
    const data = await chimera.strategies.getInfo(poolId);
    this.cache.set(cacheKey, { data, timestamp: Date.now() });
    return data;
  }
}
```

3. **Optimize Gas Usage**
```typescript
// ✅ Good - Estimate gas before transaction
const gasEstimate = await chimera.utils.estimateGas(transaction);
const gasPrice = await provider.getGasPrice();
const maxFeePerGas = gasPrice.mul(110).div(100); // 10% buffer

const tx = await contract.method({
  gasLimit: gasEstimate.mul(110).div(100), // 10% buffer
  maxFeePerGas
});
```

### Code Organization

1. **Modular Architecture**
```typescript
// services/StrategyService.ts
export class StrategyService {
  constructor(private chimera: ChimeraClient) {}
  
  async createStrategy(params: StrategyParams) {
    // Strategy creation logic
  }
  
  async monitorStrategy(poolId: string) {
    // Strategy monitoring logic
  }
}

// services/PortfolioService.ts
export class PortfolioService {
  constructor(private chimera: ChimeraClient) {}
  
  async createPortfolio(params: PortfolioParams) {
    // Portfolio creation logic
  }
}
```

2. **Configuration Management**
```typescript
// config/index.ts
export const config = {
  networks: {
    local: {
      rpcUrl: 'http://localhost:8545',
      contracts: {
        encryptedAlphaHook: '0x...',
        darkPoolEngine: '0x...'
      }
    },
    fhenixHelium: {
      rpcUrl: 'https://api.helium.fhenix.zone',
      contracts: {
        encryptedAlphaHook: '0x...',
        darkPoolEngine: '0x...'
      }
    }
  },
  encryption: {
    keyRotationInterval: 86400, // 24 hours
    batchSize: 100
  }
};
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Encryption Errors
```typescript
// Problem: Encryption fails
Error: Invalid encryption parameters

// Solution: Verify Fhenix client setup
const fhenixClient = new FhenixClient({
  provider,
  chainId: 8008135, // Correct chain ID for Fhenix Helium
});

// Test encryption
try {
  const encrypted = await fhenixClient.encrypt_uint64(1000);
  console.log('✅ Encryption working');
} catch (error) {
  console.error('❌ Encryption failed:', error);
}
```

#### 2. Gas Estimation Failures
```typescript
// Problem: Gas estimation too low
Error: Transaction failed due to gas limit

// Solution: Add gas buffer and check network conditions
const baseGasEstimate = await contract.estimateGas.method();
const gasLimit = baseGasEstimate.mul(150).div(100); // 50% buffer

// Check if network is congested
const gasPrice = await provider.getGasPrice();
if (gasPrice.gt(ethers.utils.parseUnits('100', 'gwei'))) {
  console.warn('⚠️ High gas prices detected');
}
```

#### 3. Dark Pool Execution Issues
```typescript
// Problem: Orders not executing
// Solution: Check batch conditions
const currentBatchSize = await chimera.darkPool.getCurrentBatchSize();
const lastBatchTime = await chimera.darkPool.lastBatchTime();
const batchInterval = await chimera.darkPool.batchInterval();

if (Date.now() / 1000 - lastBatchTime > batchInterval) {
  console.log('⏰ Batch ready for execution');
  await chimera.darkPool.executeBatch();
}
```

#### 4. Portfolio Rebalancing Failures
```typescript
// Problem: Rebalancing not triggering
// Solution: Check rebalance conditions
const portfolioInfo = await chimera.portfolios.getInfo(tokenId);
const timeSinceRebalance = Date.now() / 1000 - portfolioInfo.lastRebalance;

// Check if minimum time has passed
const rebalanceFrequency = 86400; // 24 hours
if (timeSinceRebalance < rebalanceFrequency) {
  console.log(`⏳ Rebalance available in ${rebalanceFrequency - timeSinceRebalance} seconds`);
}
```

### Debug Mode

```typescript
// Enable debug logging
const chimera = new ChimeraClient({
  // ... config
  debug: true,
  logLevel: 'verbose'
});

// Monitor all events
chimera.on('transaction', (tx) => {
  console.log('📄 Transaction:', tx.hash);
});

chimera.on('confirmation', (receipt) => {
  console.log('✅ Confirmed:', receipt.transactionHash);
});

chimera.on('error', (error) => {
  console.error('❌ Error:', error);
});
```

### Testing Utilities

```typescript
// test/utils/helpers.ts
export async function deployTestStrategy() {
  const params = {
    strikePrice: await fhenixClient.encrypt_uint64(1000),
    leverage: await fhenixClient.encrypt_uint64(2),
    volatility: await fhenixClient.encrypt_uint64(20),
    expiry: await fhenixClient.encrypt_uint64(
      Math.floor(Date.now() / 1000) + 86400
    )
  };
  
  return chimera.strategies.deploy({
    curveType: 'linear',
    encryptedParams: params,
    tokenA: MOCK_TOKEN_A,
    tokenB: MOCK_TOKEN_B,
    fee: 3000,
    initialPrice: '1000000000000000000000'
  });
}

export async function waitForBatchExecution() {
  return new Promise((resolve) => {
    chimera.darkPool.on('BatchExecuted', resolve);
    setTimeout(() => chimera.darkPool.executeBatch(), 1000);
  });
}
```

## 🎓 Learning Resources

### Documentation
- [Chimera Protocol Docs](https://docs.chimera.finance)
- [Fhenix Documentation](https://docs.fhenix.zone)
- [Uniswap V4 Guide](https://docs.uniswap.org/contracts/v4/overview)

### Tutorials
- [Building Your First Encrypted Strategy](https://learn.chimera.finance/encrypted-strategies)
- [Dark Pool Integration Guide](https://learn.chimera.finance/dark-pools)
- [ZK-Portfolio Management](https://learn.chimera.finance/zk-portfolios)

### Community
- [Discord](https://discord.gg/chimera)
- [GitHub](https://github.com/ChimeraProtocol)
- [Twitter](https://twitter.com/ChimeraFinance)

---

**Ready to build the future of confidential DeFi? Start creating with Chimera!** 🚀
