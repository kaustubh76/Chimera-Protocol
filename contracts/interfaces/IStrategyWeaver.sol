// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IStrategyWeaver
 * @notice Interface for confidential portfolio composition and management
 * @dev Enables encrypted asset weights and automated rebalancing
 */
interface IStrategyWeaver is IERC721 {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice ZK Portfolio NFT with encrypted composition
    struct ZKPortfolio {
        uint256 tokenId;                   // NFT token ID
        address strategist;                // Portfolio strategist
        address investor;                  // Portfolio investor
        address[] assetAddresses;          // Asset contract addresses
        euint64[] encryptedWeights;        // Encrypted asset weights
        bytes32 encryptedRebalanceStrategy; // Encrypted rebalancing strategy
        euint64 encryptedTotalValue;       // Encrypted total portfolio value
        uint256 creationTime;             // Portfolio creation timestamp
        uint256 lastRebalance;            // Last rebalancing timestamp
        bool isActive;                    // Portfolio active status
        uint256 managementFeePaid;        // Management fees paid
        uint256 performanceFeePaid;       // Performance fees paid
    }

    /// @notice Asset holding information
    struct AssetHolding {
        address assetAddress;             // Asset contract address
        euint64 encryptedBalance;         // Encrypted asset balance
        euint64 encryptedTargetWeight;    // Encrypted target weight
        uint256 lastUpdate;              // Last update timestamp
    }

    /// @notice Rebalancing rule for automated execution
    struct RebalancingRule {
        uint256 ruleId;                  // Unique rule identifier
        bytes32 encryptedCondition;      // Encrypted trigger condition
        bytes32 encryptedAction;         // Encrypted rebalancing action
        uint256 priority;                // Rule execution priority
        bool isActive;                   // Rule active status
    }

    /// @notice Portfolio performance tracking
    struct PerformanceData {
        euint64 encryptedInitialValue;    // Initial portfolio value
        euint64 encryptedCurrentValue;    // Current portfolio value
        euint64 encryptedHighWaterMark;   // High water mark for fees
        uint256 totalReturn;             // Total return percentage
        uint256 sharpeRatio;             // Risk-adjusted return metric
        uint256 maxDrawdown;             // Maximum drawdown percentage
        uint256 lastUpdate;              // Last update timestamp
    }

    /*//////////////////////////////////////////////////////////////
                        PORTFOLIO MANAGEMENT
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
    ) external returns (uint256 tokenId);

    /**
     * @notice Execute confidential rebalancing for a portfolio
     * @param tokenId Portfolio token ID
     */
    function executeRebalancing(uint256 tokenId) external;

    /**
     * @notice Add investment to portfolio
     * @param tokenId Portfolio token ID
     * @param amount Investment amount
     */
    function addInvestment(uint256 tokenId, uint256 amount) external;

    /**
     * @notice Withdraw investment from portfolio
     * @param tokenId Portfolio token ID
     * @param amount Withdrawal amount
     */
    function withdrawInvestment(uint256 tokenId, uint256 amount) external;

    /**
     * @notice Authorize strategist
     * @param strategist Strategist address
     * @param authorized Authorization status
     */
    function authorizeStrategist(address strategist, bool authorized) external;

    /**
     * @notice Emergency pause
     */
    function pause() external;

    /**
     * @notice Unpause
     */
    function unpause() external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get strategist's portfolios
     * @param strategist Strategist address
     * @return portfolioIds Array of portfolio token IDs
     */
    function getStrategistPortfolios(address strategist) external view returns (uint256[] memory);

    /**
     * @notice Get portfolio asset holdings
     * @param tokenId Portfolio token ID
     * @return assetAddresses Array of asset addresses
     * @return holdingsArray Array of asset holdings
     */
    function getPortfolioHoldings(uint256 tokenId) external view returns (
        address[] memory assetAddresses,
        AssetHolding[] memory holdingsArray
    );

    /**
     * @notice Get portfolio performance data
     * @param tokenId Portfolio token ID
     * @return performance Performance data struct
     */
    function getPortfolioPerformance(uint256 tokenId) external view returns (PerformanceData memory);
}
