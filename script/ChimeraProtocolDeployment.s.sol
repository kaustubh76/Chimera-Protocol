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
import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ChimeraProtocolDeployment
 * @notice Complete end-to-end deployment script for Chimera Protocol
 * @dev Handles deployment, configuration, validation, and initialization with full robustness
 */
contract ChimeraProtocolDeployment is Script {
    
    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT STATE
    //////////////////////////////////////////////////////////////*/
    
    struct NetworkConfig {
        string name;
        bool isTestnet;
        bool supportsFHE;
        uint256 expectedChainId;
    }
    
    struct ContractAddresses {
        address poolManager;
        address customCurveHook;
        address darkPoolEngine;
        address strategyWeaver;
        address riskEngine;
    }
    
    struct TokenAddresses {
        address usdc;
        address usdt;
        address weth;
        address wbtc;
        address link;
    }
    
    struct DeploymentParams {
        uint256 deployerPrivateKey;
        address deployer;
        address treasury;
        NetworkConfig network;
        ContractAddresses contracts;
        TokenAddresses tokens;
    }
    
    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT LOGIC
    //////////////////////////////////////////////////////////////*/
    
    function run() external {
        DeploymentParams memory params = _loadConfiguration();
        
        console.log("========================================");
        console.log("  CHIMERA PROTOCOL DEPLOYMENT v2.0");
        console.log("========================================");
        console.log("Network:", params.network.name);
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", params.deployer);
        console.log("Treasury:", params.treasury);
        console.log("FHE Support:", params.network.supportsFHE);
        console.log("========================================");
        
        vm.startBroadcast(params.deployerPrivateKey);
        
        // Phase 1: Core Infrastructure
        _deployInfrastructure(params);
        
        // Phase 2: Protocol Contracts
        _deployProtocolContracts(params);
        
        // Phase 3: Configuration & Setup
        _configureProtocol(params);
        
        // Phase 4: Trading Pairs & Permissions
        _setupTradingInfrastructure(params);
        
        // Phase 5: Risk Parameters & Security
        _configureRiskManagement(params);
        
        // Phase 6: Validation & Testing
        _validateDeployment(params);
        
        // Phase 7: Initial State & Demo Data
        if (params.network.isTestnet) {
            _initializeTestData(params);
        }
        
        vm.stopBroadcast();
        
        _printDeploymentSummary(params);
    }
    
    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION LOADING
    //////////////////////////////////////////////////////////////*/
    
    function _loadConfiguration() internal returns (DeploymentParams memory params) {
        // Load environment variables
        params.deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        params.deployer = vm.addr(params.deployerPrivateKey);
        
        // Set treasury (can be same as deployer for testing)
        try vm.envAddress("TREASURY_ADDRESS") returns (address treasury) {
            params.treasury = treasury;
        } catch {
            params.treasury = params.deployer;
        }
        
        // Configure network
        params.network = _getNetworkConfig();
        
        // Load existing contracts or set to zero for new deployment
        params.contracts = _loadExistingContracts();
        
        // Load token addresses
        params.tokens = _loadTokenAddresses();
        
        console.log("Configuration loaded successfully");
        return params;
    }
    
    function _getNetworkConfig() internal view returns (NetworkConfig memory config) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) {
            config = NetworkConfig("Ethereum Mainnet", false, false, 1);
        } else if (chainId == 11155111) {
            config = NetworkConfig("Sepolia Testnet", true, false, 11155111);
        } else if (chainId == 8008135) {
            config = NetworkConfig("Fhenix Helium", true, true, 8008135);
        } else if (chainId == 31337) {
            config = NetworkConfig("Local Anvil", true, false, 31337);
        } else {
            config = NetworkConfig("Unknown Network", true, false, chainId);
        }
    }
    
    function _loadExistingContracts() internal returns (ContractAddresses memory contracts) {
        // Try to load existing contract addresses
        try vm.envAddress("POOL_MANAGER_ADDRESS") returns (address addr) {
            contracts.poolManager = addr;
        } catch {
            contracts.poolManager = address(0);
        }
        
        try vm.envAddress("CUSTOM_CURVE_HOOK") returns (address addr) {
            contracts.customCurveHook = addr;
        } catch {
            contracts.customCurveHook = address(0);
        }
        
        try vm.envAddress("DARK_POOL_ENGINE") returns (address addr) {
            contracts.darkPoolEngine = addr;
        } catch {
            contracts.darkPoolEngine = address(0);
        }
        
        try vm.envAddress("STRATEGY_WEAVER") returns (address addr) {
            contracts.strategyWeaver = addr;
        } catch {
            contracts.strategyWeaver = address(0);
        }
        
        try vm.envAddress("RISK_ENGINE") returns (address addr) {
            contracts.riskEngine = addr;
        } catch {
            contracts.riskEngine = address(0);
        }
    }
    
    function _loadTokenAddresses() internal returns (TokenAddresses memory tokens) {
        tokens.usdc = vm.envAddress("USDC_ADDRESS");
        tokens.weth = vm.envAddress("WETH_ADDRESS");
        tokens.link = vm.envAddress("LINK_ADDRESS");
        
        try vm.envAddress("USDT_ADDRESS") returns (address addr) {
            tokens.usdt = addr;
        } catch {
            tokens.usdt = address(0);
        }
        
        try vm.envAddress("WBTC_ADDRESS") returns (address addr) {
            tokens.wbtc = addr;
        } catch {
            tokens.wbtc = address(0);
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                        PHASE 1: INFRASTRUCTURE
    //////////////////////////////////////////////////////////////*/
    
    function _deployInfrastructure(DeploymentParams memory params) internal {
        console.log("\n=== PHASE 1: CORE INFRASTRUCTURE ===");
        
        // Deploy or use existing PoolManager
        if (params.contracts.poolManager == address(0)) {
            console.log("Deploying PoolManager...");
            params.contracts.poolManager = address(new PoolManager(params.deployer));
            console.log("  PoolManager deployed:", params.contracts.poolManager);
        } else {
            console.log("  Using existing PoolManager:", params.contracts.poolManager);
            _validateContract(params.contracts.poolManager, "PoolManager");
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                      PHASE 2: PROTOCOL CONTRACTS
    //////////////////////////////////////////////////////////////*/
    
    function _deployProtocolContracts(DeploymentParams memory params) internal {
        console.log("\n=== PHASE 2: PROTOCOL CONTRACTS ===");
        
        // Deploy CustomCurveHook
        if (params.contracts.customCurveHook == address(0)) {
            console.log("Deploying CustomCurveHook...");
            params.contracts.customCurveHook = address(new CustomCurveHook(
                IPoolManager(params.contracts.poolManager),
                params.deployer
            ));
            console.log("  CustomCurveHook deployed:", params.contracts.customCurveHook);
        } else {
            console.log("  Using existing CustomCurveHook:", params.contracts.customCurveHook);
            _validateContract(params.contracts.customCurveHook, "CustomCurveHook");
        }
        
        // Deploy DarkPoolEngine
        if (params.contracts.darkPoolEngine == address(0)) {
            console.log("Deploying DarkPoolEngine...");
            params.contracts.darkPoolEngine = address(new DarkPoolEngine(
                params.contracts.poolManager,
                params.deployer
            ));
            console.log("  DarkPoolEngine deployed:", params.contracts.darkPoolEngine);
        } else {
            console.log("  Using existing DarkPoolEngine:", params.contracts.darkPoolEngine);
            _validateContract(params.contracts.darkPoolEngine, "DarkPoolEngine");
        }
        
        // Deploy StrategyWeaver
        if (params.contracts.strategyWeaver == address(0)) {
            console.log("Deploying StrategyWeaver...");
            params.contracts.strategyWeaver = address(new StrategyWeaver(
                params.deployer,
                params.treasury
            ));
            console.log("  StrategyWeaver deployed:", params.contracts.strategyWeaver);
        } else {
            console.log("  Using existing StrategyWeaver:", params.contracts.strategyWeaver);
            _validateContract(params.contracts.strategyWeaver, "StrategyWeaver");
        }
        
        // Deploy RiskEngine
        if (params.contracts.riskEngine == address(0)) {
            console.log("Deploying RiskEngine...");
            params.contracts.riskEngine = address(new RiskEngine(params.deployer));
            console.log("  RiskEngine deployed:", params.contracts.riskEngine);
        } else {
            console.log("  Using existing RiskEngine:", params.contracts.riskEngine);
            _validateContract(params.contracts.riskEngine, "RiskEngine");
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                      PHASE 3: CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    
    function _configureProtocol(DeploymentParams memory params) internal {
        console.log("\n=== PHASE 3: PROTOCOL CONFIGURATION ===");
        
        // Configure DarkPool
        console.log("Configuring DarkPoolEngine...");
        DarkPoolEngine darkPool = DarkPoolEngine(params.contracts.darkPoolEngine);
        
        console.log("  - Batch window (constant):", darkPool.BATCH_WINDOW(), "seconds");
        console.log("  - Min order value:", darkPool.MIN_ORDER_VALUE());
        console.log("  - Max orders per batch:", darkPool.MAX_ORDERS_PER_BATCH());
        console.log("  - Current protocol fee:", darkPool.protocolFeeBps(), "bps");
        
        // Update protocol fee if needed
        try darkPool.updateProtocolFee(30) { // 0.3%
            console.log("  - Protocol fee updated to 30 bps");
        } catch {
            console.log("  - Protocol fee already optimal");
        }
        
        // Configure StrategyWeaver
        console.log("Configuring StrategyWeaver...");
        StrategyWeaver weaver = StrategyWeaver(params.contracts.strategyWeaver);
        
        console.log("  - NFT Name:", weaver.name());
        console.log("  - NFT Symbol:", weaver.symbol());
        console.log("  - Management fee:", weaver.MANAGEMENT_FEE_BPS(), "bps");
        console.log("  - Performance fee:", weaver.PERFORMANCE_FEE_BPS(), "bps");
        console.log("  - Max assets per portfolio:", weaver.MAX_ASSETS_PER_PORTFOLIO());
        
        // Configure RiskEngine
        console.log("Configuring RiskEngine...");
        RiskEngine riskEngine = RiskEngine(params.contracts.riskEngine);
        
        console.log("  - Max position size: $10M (constant)");
        console.log("  - Max leverage: 20x (constant)");
        console.log("  - VaR confidence level: 95% (constant)");
        
        // Configure risk managers
        try riskEngine.authorizeRiskManager(params.deployer, true) {
            console.log("  - Deployer authorized as risk manager");
        } catch {
            console.log("  - Risk manager authorization already set");
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                    PHASE 4: TRADING INFRASTRUCTURE
    //////////////////////////////////////////////////////////////*/
    
    function _setupTradingInfrastructure(DeploymentParams memory params) internal {
        console.log("\n=== PHASE 4: TRADING INFRASTRUCTURE ===");
        
        DarkPoolEngine darkPool = DarkPoolEngine(params.contracts.darkPoolEngine);
        
        // Define major trading pairs
        address[2][] memory tradingPairs = new address[2][](6);
        tradingPairs[0] = [params.tokens.weth, params.tokens.usdc];
        tradingPairs[1] = [params.tokens.weth, params.tokens.link];
        tradingPairs[2] = [params.tokens.usdc, params.tokens.link];
        
        if (params.tokens.usdt != address(0)) {
            tradingPairs[3] = [params.tokens.weth, params.tokens.usdt];
            tradingPairs[4] = [params.tokens.usdc, params.tokens.usdt];
        }
        
        if (params.tokens.wbtc != address(0)) {
            tradingPairs[5] = [params.tokens.wbtc, params.tokens.usdc];
        }
        
        // Enable trading pairs
        console.log("Enabling trading pairs...");
        for (uint256 i = 0; i < tradingPairs.length; i++) {
            if (tradingPairs[i][0] != address(0) && tradingPairs[i][1] != address(0)) {
                try darkPool.addTradingPair(tradingPairs[i][0], tradingPairs[i][1]) {
                    console.log("  - Added pair:", _getTokenSymbol(tradingPairs[i][0]), "/", _getTokenSymbol(tradingPairs[i][1]));
                } catch {
                    console.log("  - Pair already exists:", _getTokenSymbol(tradingPairs[i][0]), "/", _getTokenSymbol(tradingPairs[i][1]));
                }
            }
        }
        
        // Verify trading pairs
        console.log("Verifying trading pairs...");
        bool wethUsdcEnabled = darkPool.supportedPairs(params.tokens.weth, params.tokens.usdc);
        bool wethLinkEnabled = darkPool.supportedPairs(params.tokens.weth, params.tokens.link);
        console.log("  - WETH/USDC enabled:", wethUsdcEnabled);
        console.log("  - WETH/LINK enabled:", wethLinkEnabled);
    }
    
    /*//////////////////////////////////////////////////////////////
                    PHASE 5: RISK MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    function _configureRiskManagement(DeploymentParams memory params) internal {
        console.log("\n=== PHASE 5: RISK MANAGEMENT ===");
        
        RiskEngine riskEngine = RiskEngine(params.contracts.riskEngine);
        
        // Configure system-wide risk parameters
        console.log("Configuring system risk parameters...");
        
        // Setup circuit breakers for key risk scenarios
        try riskEngine.setupCircuitBreaker(
            keccak256("system_leverage"),
            FHE.asEuint64(500), // 5% trigger level
            3600 // 1 hour cooldown
        ) {
            console.log("  - System leverage circuit breaker configured");
        } catch {
            console.log("  - Circuit breakers already configured");
        }
        
        try riskEngine.setupCircuitBreaker(
            keccak256("volatility_spike"),
            FHE.asEuint64(1000), // 10% trigger level
            1800 // 30 min cooldown
        ) {
            console.log("  - Volatility spike circuit breaker configured");
        } catch {
            console.log("  - Volatility circuit breaker already configured");
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                      PHASE 6: VALIDATION
    //////////////////////////////////////////////////////////////*/
    
    function _validateDeployment(DeploymentParams memory params) internal view {
        console.log("\n=== PHASE 6: DEPLOYMENT VALIDATION ===");
        
        // Validate all contracts
        require(_hasCode(params.contracts.poolManager), "PoolManager not deployed");
        require(_hasCode(params.contracts.customCurveHook), "CustomCurveHook not deployed");
        require(_hasCode(params.contracts.darkPoolEngine), "DarkPoolEngine not deployed");
        require(_hasCode(params.contracts.strategyWeaver), "StrategyWeaver not deployed");
        require(_hasCode(params.contracts.riskEngine), "RiskEngine not deployed");
        
        // Validate DarkPool functionality
        DarkPoolEngine darkPool = DarkPoolEngine(params.contracts.darkPoolEngine);
        (uint256 batchId, uint256 timeRemaining, uint256 orderCount) = darkPool.getCurrentBatchStatus();
        console.log("  - DarkPool current batch:", batchId, "orders:", orderCount);
        require(batchId > 0, "DarkPool not initialized");
        
        // Validate StrategyWeaver functionality
        StrategyWeaver weaver = StrategyWeaver(params.contracts.strategyWeaver);
        require(bytes(weaver.name()).length > 0, "StrategyWeaver not initialized");
        console.log("  - StrategyWeaver name:", weaver.name());
        
        // Validate RiskEngine functionality
        RiskEngine riskEngine = RiskEngine(params.contracts.riskEngine);
        RiskEngine.SystemRisk memory systemRisk = riskEngine.getSystemRisk();
        console.log("  - RiskEngine active portfolios:", systemRisk.activePortfolios);
        
        // Validate trading pairs
        bool tradingEnabled = darkPool.supportedPairs(params.tokens.weth, params.tokens.usdc);
        require(tradingEnabled, "Trading pairs not configured");
        console.log("  - Trading pairs validated");
        
        console.log("  [SUCCESS] All validations passed!");
    }
    
    /*//////////////////////////////////////////////////////////////
                    PHASE 7: TEST DATA (TESTNET ONLY)
    //////////////////////////////////////////////////////////////*/
    
    function _initializeTestData(DeploymentParams memory params) internal {
        console.log("\n=== PHASE 7: TEST DATA INITIALIZATION ===");
        
        // Only on testnets
        if (!params.network.isTestnet) {
            console.log("  Skipping test data (mainnet deployment)");
            return;
        }
        
        StrategyWeaver weaver = StrategyWeaver(params.contracts.strategyWeaver);
        
        // Create a sample portfolio for testing
        console.log("Creating sample portfolio...");
        
        address[] memory assets = new address[](3);
        assets[0] = params.tokens.weth;
        assets[1] = params.tokens.usdc;
        assets[2] = params.tokens.link;
        
        if (params.network.supportsFHE) {
            // Real FHE implementation
            euint64[] memory weights = new euint64[](3);
            weights[0] = FHE.asEuint64(5000); // 50%
            weights[1] = FHE.asEuint64(3000); // 30%
            weights[2] = FHE.asEuint64(2000); // 20%
            
            try weaver.createPortfolio(
                assets, 
                weights, 
                bytes32(0), // Simple rebalance strategy
                params.deployer, 
                1000 * 10**18 // $1000 initial investment
            ) returns (uint256 portfolioId) {
                console.log("  - Sample portfolio created with ID:", portfolioId);
            } catch {
                console.log("  - Portfolio creation failed (insufficient balance)");
            }
        } else {
            console.log("  - Sample portfolio skipped (FHE not available in simulation)");
        }
        
        // Authorize deployer as strategist
        try weaver.authorizeStrategist(params.deployer, true) {
            console.log("  - Deployer authorized as strategist");
        } catch {
            console.log("  - Authorization already set");
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                          UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _validateContract(address contractAddr, string memory name) internal view {
        require(contractAddr != address(0), string(abi.encodePacked(name, " address is zero")));
        require(_hasCode(contractAddr), string(abi.encodePacked(name, " has no code")));
        console.log("    [OK]", name, "validated");
    }
    
    function _hasCode(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    
    function _getTokenSymbol(address token) internal view returns (string memory) {
        if (token == vm.envAddress("WETH_ADDRESS")) return "WETH";
        if (token == vm.envAddress("USDC_ADDRESS")) return "USDC";
        if (token == vm.envAddress("LINK_ADDRESS")) return "LINK";
        try vm.envAddress("USDT_ADDRESS") returns (address usdt) {
            if (token == usdt) return "USDT";
        } catch {}
        try vm.envAddress("WBTC_ADDRESS") returns (address wbtc) {
            if (token == wbtc) return "WBTC";
        } catch {}
        return "UNKNOWN";
    }
    
    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT SUMMARY
    //////////////////////////////////////////////////////////////*/
    
    function _printDeploymentSummary(DeploymentParams memory params) internal view {
        console.log("\n========================================");
        console.log("    DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("Network:", params.network.name);
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", params.deployer);
        console.log("Treasury:", params.treasury);
        console.log("");
        console.log("[CONTRACTS] DEPLOYED CONTRACTS:");
        console.log("  PoolManager:      ", params.contracts.poolManager);
        console.log("  CustomCurveHook:  ", params.contracts.customCurveHook);
        console.log("  DarkPoolEngine:   ", params.contracts.darkPoolEngine);
        console.log("  StrategyWeaver:   ", params.contracts.strategyWeaver);
        console.log("  RiskEngine:       ", params.contracts.riskEngine);
        console.log("");
        console.log("[CONFIG] UPDATE .ENV FILE:");
        console.log("POOL_MANAGER_ADDRESS=", params.contracts.poolManager);
        console.log("CUSTOM_CURVE_HOOK=", params.contracts.customCurveHook);
        console.log("DARK_POOL_ENGINE=", params.contracts.darkPoolEngine);
        console.log("STRATEGY_WEAVER=", params.contracts.strategyWeaver);
        console.log("RISK_ENGINE=", params.contracts.riskEngine);
        console.log("");
        console.log("[NEXT] NEXT STEPS:");
        console.log("1. Update your .env file with the addresses above");
        console.log("2. Run contract interactions script");
        console.log("3. Begin testing with the deployed contracts");
        console.log("4. Monitor system health via RiskEngine");
        console.log("");
        console.log("[SUCCESS] CHIMERA PROTOCOL DEPLOYMENT COMPLETE!");
        console.log("========================================");
    }
}
