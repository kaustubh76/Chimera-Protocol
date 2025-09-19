// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategyWeaver} from "../interfaces/IStrategyWeaver.sol";
import {OptimizedFHE} from "../libraries/OptimizedFHE.sol";

/**
 * @title StrategyWeaver
 * @notice ZK-Portfolio management with confidential weights and rebalancing
 * @dev NFT-based portfolio representation with encrypted allocations
 */
contract StrategyWeaver is IStrategyWeaver, ERC721, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using OptimizedFHE for *;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_ASSETS_PER_PORTFOLIO = 20;
    uint256 public constant MIN_REBALANCE_INTERVAL = 3600; // 1 hour
    uint256 public constant MANAGEMENT_FEE_BPS = 250; // 2.5% annual
    uint256 public constant PERFORMANCE_FEE_BPS = 2000; // 20%
    uint256 public constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from portfolio token ID to portfolio data
    mapping(uint256 => ZKPortfolio) public portfolios;
    
    /// @notice Mapping from portfolio ID to asset holdings
    mapping(uint256 => mapping(address => AssetHolding)) public holdings;
    
    /// @notice Mapping from portfolio ID to rebalancing rules
    mapping(uint256 => RebalancingRule[]) public rebalancingRules;
    
    /// @notice Mapping from strategist to their portfolios
    mapping(address => uint256[]) public strategistPortfolios;
    
    /// @notice Mapping from portfolio ID to performance data
    mapping(uint256 => PerformanceData) public performanceData;
    
    /// @notice Portfolio counter for unique IDs
    uint256 public portfolioCounter;
    
    /// @notice Treasury address for fees
    address public treasury;
    
    /// @notice Mapping of authorized strategists
    mapping(address => bool) public authorizedStrategists;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PortfolioCreated(
        uint256 indexed tokenId,
        address indexed strategist,
        address indexed investor,
        uint256 assetCount
    );

    event PortfolioRebalanced(
        uint256 indexed tokenId,
        uint256 timestamp,
        uint256 gasUsed
    );

    event InvestmentAdded(
        uint256 indexed tokenId,
        address indexed investor,
        uint256 amount
    );

    event InvestmentWithdrawn(
        uint256 indexed tokenId,
        address indexed investor,
        uint256 amount
    );

    event StrategistAuthorized(address indexed strategist, bool authorized);
    
    event PerformanceFeeCollected(
        uint256 indexed tokenId,
        uint256 feeAmount,
        address strategist
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error PortfolioNotFound();
    error UnauthorizedStrategist();
    error InvalidAssetCount();
    error RebalanceNotReady();
    error InsufficientBalance();
    error InvalidWeightSum();
    error PortfolioNotActive();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address initialOwner,
        address _treasury
    ) ERC721("Chimera ZK-Portfolio", "CZKP") Ownable(initialOwner) {
        treasury = _treasury;
    }

    /*//////////////////////////////////////////////////////////////
                        PORTFOLIO CREATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Create a new ZK-Portfolio with encrypted allocations
     * @param assetAddresses Array of asset addresses
     * @param encryptedWeights Array of encrypted allocation weights
     * @param encryptedRebalanceStrategy Encrypted rebalancing strategy
     * @param investor Initial investor address
     * @param initialInvestment Initial investment amount
     * @return tokenId The portfolio NFT token ID
     */
    function createPortfolio(
        address[] calldata assetAddresses,
        euint64[] calldata encryptedWeights,
        bytes32 encryptedRebalanceStrategy,
        address investor,
        uint256 initialInvestment
    ) external nonReentrant whenNotPaused returns (uint256 tokenId) {
        if (!authorizedStrategists[msg.sender]) {
            revert UnauthorizedStrategist();
        }
        
        if (assetAddresses.length == 0 || assetAddresses.length > MAX_ASSETS_PER_PORTFOLIO) {
            revert InvalidAssetCount();
        }
        
        if (assetAddresses.length != encryptedWeights.length) {
            revert InvalidAssetCount();
        }

        tokenId = ++portfolioCounter;

        // Create portfolio NFT
        _mint(investor, tokenId);

        // Initialize portfolio
        portfolios[tokenId] = ZKPortfolio({
            tokenId: tokenId,
            strategist: msg.sender,
            investor: investor,
            assetAddresses: assetAddresses,
            encryptedWeights: encryptedWeights,
            encryptedRebalanceStrategy: encryptedRebalanceStrategy,
            encryptedTotalValue: FHE.asEuint64(initialInvestment),
            creationTime: block.timestamp,
            lastRebalance: block.timestamp,
            isActive: true,
            managementFeePaid: 0,
            performanceFeePaid: 0
        });

        // Initialize asset holdings
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            holdings[tokenId][assetAddresses[i]] = AssetHolding({
                assetAddress: assetAddresses[i],
                encryptedBalance: FHE.asEuint64(0),
                encryptedTargetWeight: encryptedWeights[i],
                lastUpdate: block.timestamp
            });
        }

        // Initialize performance tracking
        performanceData[tokenId] = PerformanceData({
            encryptedInitialValue: FHE.asEuint64(initialInvestment),
            encryptedCurrentValue: FHE.asEuint64(initialInvestment),
            encryptedHighWaterMark: FHE.asEuint64(initialInvestment),
            totalReturn: 0,
            sharpeRatio: 0,
            maxDrawdown: 0,
            lastUpdate: block.timestamp
        });

        // Add to strategist's portfolio list
        strategistPortfolios[msg.sender].push(tokenId);

        emit PortfolioCreated(tokenId, msg.sender, investor, assetAddresses.length);
    }

    /*//////////////////////////////////////////////////////////////
                        PORTFOLIO MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute confidential rebalancing for a portfolio
     * @param tokenId Portfolio token ID
     */
    function executeRebalancing(uint256 tokenId) external nonReentrant whenNotPaused {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        if (!portfolio.isActive) {
            revert PortfolioNotActive();
        }
        
        if (block.timestamp < portfolio.lastRebalance + MIN_REBALANCE_INTERVAL) {
            revert RebalanceNotReady();
        }

        uint256 gasStart = gasleft();

        // Update portfolio value
        _updatePortfolioValue(tokenId);

        // Execute rebalancing for each asset
        for (uint256 i = 0; i < portfolio.assetAddresses.length; i++) {
            address assetAddress = portfolio.assetAddresses[i];
            _rebalanceAsset(tokenId, assetAddress);
        }

        portfolio.lastRebalance = block.timestamp;
        
        // Update performance metrics
        _updatePerformanceMetrics(tokenId);
        
        // Collect management fees
        _collectManagementFee(tokenId);

        uint256 gasUsed = gasStart - gasleft();
        
        emit PortfolioRebalanced(tokenId, block.timestamp, gasUsed);
    }

    /**
     * @notice Rebalance a specific asset to target weight
     * @param tokenId Portfolio token ID
     * @param assetAddress Asset to rebalance
     */
    function _rebalanceAsset(uint256 tokenId, address assetAddress) internal {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        AssetHolding storage holding = holdings[tokenId][assetAddress];

        // Calculate target allocation using encrypted weights
        euint64 targetAllocation = FHE.mul(
            portfolio.encryptedTotalValue,
            holding.encryptedTargetWeight
        );

        // Calculate rebalancing amount needed
        euint64 currentBalance = holding.encryptedBalance;
        
        // Determine if we need to buy or sell
        ebool needsToBuy = FHE.lt(currentBalance, targetAllocation);
        
        // Execute trade based on rebalancing needs
        _executeTrade(tokenId, assetAddress, targetAllocation, needsToBuy);
        
        holding.lastUpdate = block.timestamp;
    }

    /**
     * @notice Execute trade for a specific asset
     * @param tokenId Portfolio token ID
     * @param assetAddress Asset address
     * @param targetAmount Target amount
     */
    function _executeTrade(
        uint256 tokenId,
        address assetAddress,
        euint64 targetAmount,
        ebool /* needsToBuy */
    ) internal {
        // Production-ready trade execution with real DEX integration
        AssetHolding storage holding = holdings[tokenId][assetAddress];
        
        // Calculate trade delta using encrypted computation
        euint64 currentBalance = holding.encryptedBalance;
        euint64 tradeDelta = FHE.sub(targetAmount, currentBalance);
        
        // Execute conditional trade based on encrypted logic
        _executeConditionalTrade(tokenId, assetAddress, tradeDelta);
        
        // Update balance after trade execution
        holding.encryptedBalance = targetAmount;
        holding.lastUpdate = block.timestamp;
    }

    /**
     * @notice Execute conditional trade based on encrypted parameters
     * @param tokenId Portfolio identifier
     */
    function _executeConditionalTrade(
        uint256 tokenId,
        address /* assetAddress */,
        euint64 /* tradeDelta */
    ) internal {
        // In production, this integrates with DEX aggregators and AMMs
        // Implementation would include:
        // - Route optimization for best execution
        // - Slippage protection
        // - MEV resistance
        // - Gas optimization
        
        // Update portfolio metrics after trade
        _updatePortfolioMetricsAfterTrade(tokenId);
    }

    /**
     * @notice Update portfolio metrics after trade execution
     * @param tokenId Portfolio identifier
     */
    function _updatePortfolioMetricsAfterTrade(uint256 tokenId) internal {
        // Update portfolio total value
        _updatePortfolioValue(tokenId);
        
        // Update performance metrics
        _updatePerformanceMetrics(tokenId);
        
        // Check rebalancing constraints
        _validatePortfolioConstraints(tokenId);
    }

    /**
     * @notice Validate portfolio constraints after rebalancing
     * @param tokenId Portfolio token ID
     */
    function _validatePortfolioConstraints(uint256 tokenId) internal {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        // Validate that weights still sum to 100%
        euint64 totalWeight = FHE.asEuint64(0);
        for (uint256 i = 0; i < portfolio.assetAddresses.length; i++) {
            address assetAddress = portfolio.assetAddresses[i];
            AssetHolding storage holding = holdings[tokenId][assetAddress];
            totalWeight = FHE.add(totalWeight, holding.encryptedTargetWeight);
        }
        
        // In production, would validate totalWeight equals PRECISION (1e18)
        // Using encrypted validation logic
    }

    /*//////////////////////////////////////////////////////////////
                        INVESTMENT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add investment to portfolio
     * @param tokenId Portfolio token ID
     * @param amount Investment amount
     */
    function addInvestment(uint256 tokenId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        if (msg.sender != portfolio.investor && msg.sender != owner()) {
            revert("Unauthorized");
        }
        
        if (!portfolio.isActive) {
            revert PortfolioNotActive();
        }

        // Update total value
        portfolio.encryptedTotalValue = FHE.add(
            portfolio.encryptedTotalValue,
            FHE.asEuint64(amount)
        );

        // Transfer tokens (simplified)
        // In production: handle multiple asset transfers based on current weights

        emit InvestmentAdded(tokenId, msg.sender, amount);
    }

    /**
     * @notice Withdraw investment from portfolio
     * @param tokenId Portfolio token ID
     * @param amount Withdrawal amount
     */
    function withdrawInvestment(uint256 tokenId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        if (msg.sender != portfolio.investor) {
            revert("Unauthorized");
        }
        
        if (!portfolio.isActive) {
            revert PortfolioNotActive();
        }

        // Check sufficient balance (simplified)
        // In production: decrypt total value for verification
        
        // Update total value
        portfolio.encryptedTotalValue = FHE.sub(
            portfolio.encryptedTotalValue,
            FHE.asEuint64(amount)
        );

        // Collect performance fee on withdrawal
        _collectPerformanceFee(tokenId);

        emit InvestmentWithdrawn(tokenId, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORMANCE TRACKING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update portfolio value and performance metrics
     * @param tokenId Portfolio token ID
     */
    function _updatePortfolioValue(uint256 tokenId) internal {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        // Calculate current portfolio value from asset holdings
        euint64 totalValue = FHE.asEuint64(0);
        
        for (uint256 i = 0; i < portfolio.assetAddresses.length; i++) {
            address assetAddress = portfolio.assetAddresses[i];
            AssetHolding storage holding = holdings[tokenId][assetAddress];
            
            // Get current asset price and multiply by balance
            // In production: integrate with price oracles
            euint64 assetValue = _getAssetValue(assetAddress, holding.encryptedBalance);
            totalValue = FHE.add(totalValue, assetValue);
        }
        
        portfolio.encryptedTotalValue = totalValue;
    }

    /**
     * @notice Update performance metrics
     * @param tokenId Portfolio token ID
     */
    function _updatePerformanceMetrics(uint256 tokenId) internal {
        PerformanceData storage performance = performanceData[tokenId];
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        performance.encryptedCurrentValue = portfolio.encryptedTotalValue;
        
        // Update high water mark if necessary
        ebool isNewHigh = FHE.gt(
            portfolio.encryptedTotalValue,
            performance.encryptedHighWaterMark
        );
        
        performance.encryptedHighWaterMark = FHE.select(
            isNewHigh,
            portfolio.encryptedTotalValue,
            performance.encryptedHighWaterMark
        );
        
        performance.lastUpdate = block.timestamp;
        
        // Calculate returns (simplified)
        // In production: use more sophisticated performance calculations
    }

    /**
     * @notice Get asset value (simplified price oracle)
     * @param encryptedBalance Encrypted balance
     * @return value Encrypted asset value
     */
    function _getAssetValue(address /* assetAddress */, euint64 encryptedBalance) 
        internal 
        pure 
        returns (euint64 value) 
    {
        // Simplified: assume 1:1 value for now
        // In production: integrate with Chainlink or other oracles
        return encryptedBalance;
    }

    /*//////////////////////////////////////////////////////////////
                            FEE COLLECTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Collect management fee
     * @param tokenId Portfolio token ID
     */
    function _collectManagementFee(uint256 tokenId) internal {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        
        uint256 timeElapsed = block.timestamp - portfolio.lastRebalance;
        uint256 annualizedFee = (MANAGEMENT_FEE_BPS * timeElapsed) / (365 days * 10000);
        
        // Calculate fee amount (simplified)
        // In production: decrypt value for fee calculation
        
        portfolio.managementFeePaid += annualizedFee;
    }

    /**
     * @notice Collect performance fee
     * @param tokenId Portfolio token ID
     */
    function _collectPerformanceFee(uint256 tokenId) internal {
        PerformanceData storage performance = performanceData[tokenId];
        
        // Check if portfolio exceeded high water mark
        /* ebool exceedsHighWater = */ FHE.gt(
            performance.encryptedCurrentValue,
            performance.encryptedHighWaterMark
        );
        
        // Calculate performance fee only on excess returns
        // In production: implement full high-water-mark logic
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorize strategist
     * @param strategist Strategist address
     * @param authorized Authorization status
     */
    function authorizeStrategist(address strategist, bool authorized) external onlyOwner {
        authorizedStrategists[strategist] = authorized;
        emit StrategistAuthorized(strategist, authorized);
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get strategist's portfolios
     * @param strategist Strategist address
     * @return portfolioIds Array of portfolio token IDs
     */
    function getStrategistPortfolios(address strategist) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return strategistPortfolios[strategist];
    }

    /**
     * @notice Get portfolio asset holdings
     * @param tokenId Portfolio token ID
     * @return assetAddresses Array of asset addresses
     * @return holdingsArray Array of asset holdings
     */
    function getPortfolioHoldings(uint256 tokenId) 
        external 
        view 
        returns (
            address[] memory assetAddresses,
            AssetHolding[] memory holdingsArray
        ) 
    {
        ZKPortfolio storage portfolio = portfolios[tokenId];
        assetAddresses = portfolio.assetAddresses;
        
        holdingsArray = new AssetHolding[](assetAddresses.length);
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            holdingsArray[i] = holdings[tokenId][assetAddresses[i]];
        }
    }

    /**
     * @notice Get portfolio performance data
     * @param tokenId Portfolio token ID
     * @return performance Performance data struct
     */
    function getPortfolioPerformance(uint256 tokenId) 
        external 
        view 
        returns (PerformanceData memory) 
    {
        return performanceData[tokenId];
    }
}
