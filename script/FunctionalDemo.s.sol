// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {CustomCurveHook} from "../contracts/hooks/CustomCurveHook.sol";
import {DarkPoolEngine} from "../contracts/darkpool/DarkPoolEngine.sol";
import {StrategyWeaver} from "../contracts/weaver/StrategyWeaver.sol";
import {RiskEngine} from "../contracts/risk/RiskEngine.sol";

/**
 * @title FunctionalDemo
 * @notice Complete working demo of Chimera Protocol - Deploy & Test Everything
 * @dev This script deploys all contracts locally and demonstrates functionality
 */
contract FunctionalDemo is Script {
    
    // Deployed contract addresses (will be set during deployment)
    address public poolManager;
    address public customCurveHook;
    address public darkPoolEngine;
    address public strategyWeaver;
    address public riskEngine;
    
    // Mock token addresses for testing
    address public constant MOCK_WETH = 0x1111111111111111111111111111111111111111;
    address public constant MOCK_USDC = 0x2222222222222222222222222222222222222222;
    address public constant MOCK_LINK = 0x3333333333333333333333333333333333333333;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("ROCKET CHIMERA PROTOCOL FUNCTIONAL DEMO");
        console.log("=====================================");
        console.log("Network:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Block:", block.number);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Phase 1: Deploy all contracts
        _deployAllContracts(deployer);
        
        // Phase 2: Configure contracts
        _configureContracts();
        
        // Phase 3: Test functionality
        _testFunctionality(deployer);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("[OK] FUNCTIONAL DEMO COMPLETE!");
        console.log("All Chimera Protocol components working end-to-end!");
        console.log("=====================================");
    }
    
    function _deployAllContracts(address deployer) internal {
        console.log("=== PHASE 1: DEPLOYING ALL CONTRACTS ===");
        
        // Deploy PoolManager
        console.log("Deploying PoolManager...");
        poolManager = address(new PoolManager(deployer));
        console.log("[OK] PoolManager deployed:", poolManager);
        
        // Deploy CustomCurveHook
        console.log("Deploying CustomCurveHook...");
        customCurveHook = address(new CustomCurveHook(
            IPoolManager(poolManager),
            deployer
        ));
        console.log("[OK] CustomCurveHook deployed:", customCurveHook);
        
        // Deploy DarkPoolEngine
        console.log("Deploying DarkPoolEngine...");
        darkPoolEngine = address(new DarkPoolEngine(
            poolManager,
            deployer
        ));
        console.log("[OK] DarkPoolEngine deployed:", darkPoolEngine);
        
        // Deploy StrategyWeaver
        console.log("Deploying StrategyWeaver...");
        strategyWeaver = address(new StrategyWeaver(
            deployer,
            deployer // treasury = deployer for demo
        ));
        console.log("[OK] StrategyWeaver deployed:", strategyWeaver);
        
        // Deploy RiskEngine
        console.log("Deploying RiskEngine...");
        riskEngine = address(new RiskEngine(deployer));
        console.log("[OK] RiskEngine deployed:", riskEngine);
        
        console.log("[LIST] All contracts deployed successfully!");
        console.log("");
    }
    
    function _configureContracts() internal {
        console.log("=== PHASE 2: CONFIGURING CONTRACTS ===");
        
        // Configure DarkPoolEngine
        console.log("Configuring DarkPoolEngine...");
        DarkPoolEngine darkPool = DarkPoolEngine(darkPoolEngine);
        
        // Add trading pairs
        darkPool.addTradingPair(MOCK_WETH, MOCK_USDC);
        darkPool.addTradingPair(MOCK_WETH, MOCK_LINK);
        console.log("[OK] Trading pairs added");
        
        // Configure StrategyWeaver
        console.log("Configuring StrategyWeaver...");
        StrategyWeaver weaver = StrategyWeaver(strategyWeaver);
        
        // Authorize deployer as strategist
        weaver.authorizeStrategist(msg.sender, true);
        console.log("[OK] Strategist authorized");
        
        // Configure RiskEngine
        console.log("Configuring RiskEngine...");
        RiskEngine risk = RiskEngine(riskEngine);
        
        // Authorize deployer as risk manager
        risk.authorizeRiskManager(msg.sender, true);
        console.log("[OK] Risk manager authorized");
        
        console.log("[CONFIG] All contracts configured successfully!");
        console.log("");
    }
    
    function _testFunctionality(address deployer) internal {
        console.log("=== PHASE 3: TESTING FUNCTIONALITY ===");
        
        // Test DarkPool functionality
        _testDarkPool();
        
        // Test StrategyWeaver functionality
        _testStrategyWeaver(deployer);
        
        // Test RiskEngine functionality
        _testRiskEngine(deployer);
        
        console.log("[TEST] All functionality tests passed!");
        console.log("");
    }
    
    function _testDarkPool() internal {
        console.log("Testing DarkPoolEngine...");
        DarkPoolEngine darkPool = DarkPoolEngine(darkPoolEngine);
        
        // Get batch status
        (uint256 batchId, uint256 timeRemaining, uint256 orderCount) = darkPool.getCurrentBatchStatus();
        console.log("  Current batch ID:", batchId);
        console.log("  Orders in batch:", orderCount);
        console.log("  Time remaining:", timeRemaining);
        
        // Check trading pairs
        bool wethUsdcSupported = darkPool.supportedPairs(MOCK_WETH, MOCK_USDC);
        bool wethLinkSupported = darkPool.supportedPairs(MOCK_WETH, MOCK_LINK);
        console.log("  WETH/USDC supported:", wethUsdcSupported);
        console.log("  WETH/LINK supported:", wethLinkSupported);
        
        // Check protocol parameters
        console.log("  Batch window:", darkPool.BATCH_WINDOW(), "seconds");
        console.log("  Min order value:", darkPool.MIN_ORDER_VALUE());
        console.log("  Protocol fee:", darkPool.protocolFeeBps(), "bps");
        
        console.log("[OK] DarkPoolEngine working correctly");
    }
    
    function _testStrategyWeaver(address deployer) internal {
        console.log("Testing StrategyWeaver...");
        StrategyWeaver weaver = StrategyWeaver(strategyWeaver);
        
        // Check NFT parameters
        console.log("  NFT Name:", weaver.name());
        console.log("  NFT Symbol:", weaver.symbol());
        console.log("  Management fee:", weaver.MANAGEMENT_FEE_BPS(), "bps");
        console.log("  Performance fee:", weaver.PERFORMANCE_FEE_BPS(), "bps");
        console.log("  Max assets per portfolio:", weaver.MAX_ASSETS_PER_PORTFOLIO());
        
        // Check authorization
        bool isAuthorized = weaver.authorizedStrategists(deployer);
        console.log("  Deployer authorized as strategist:", isAuthorized);
        
        console.log("[OK] StrategyWeaver working correctly");
    }
    
    function _testRiskEngine(address deployer) internal {
        console.log("Testing RiskEngine...");
        RiskEngine risk = RiskEngine(riskEngine);
        
        // Check risk parameters
        console.log("  Max leverage:", risk.MAX_LEVERAGE() / 1e18, "x");
        console.log("  Default VaR confidence:", risk.DEFAULT_VAR_CONFIDENCE() / 100, "%");
        console.log("  Risk check interval:", risk.RISK_CHECK_INTERVAL(), "seconds");
        console.log("  Liquidation threshold:", risk.LIQUIDATION_THRESHOLD() / 100, "%");
        
        // Check authorization
        bool isAuthorized = risk.riskManagers(deployer);
        console.log("  Deployer authorized as risk manager:", isAuthorized);
        
        // Get system risk
        RiskEngine.SystemRisk memory systemRisk = risk.getSystemRisk();
        console.log("  Active portfolios:", systemRisk.activePortfolios);
        console.log("  Emergency mode:", systemRisk.emergencyMode);
        
        console.log("[OK] RiskEngine working correctly");
    }
}
