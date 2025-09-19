// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title IDarkPoolEngine
 * @notice Interface for confidential order processing and MEV protection
 * @dev Enables private trading through encrypted order batching
 */
interface IDarkPoolEngine {
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Order status tracking
    enum OrderStatus {
        PENDING,         // Waiting in queue
        EXECUTED,        // Successfully executed
        CANCELLED,       // Cancelled by user
        EXPIRED          // Expired due to deadline
    }

    /// @notice Batch execution status
    enum BatchStatus {
        COLLECTING,      // Collecting orders
        EXECUTED,        // Batch executed
        FAILED           // Batch execution failed
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Confidential order structure with encrypted parameters
    struct ConfidentialOrder {
        address trader;                    // Order submitter
        address tokenIn;                   // Input token
        address tokenOut;                  // Output token
        euint64 encryptedAmountIn;         // Encrypted input amount
        euint64 encryptedMinAmountOut;     // Encrypted minimum output
        euint64 encryptedMaxSlippage;      // Encrypted slippage tolerance
        uint256 deadline;                  // Order expiration
        uint256 batchId;                   // Assigned batch ID
        OrderStatus status;                // Current status
        uint256 submissionTime;            // When order was submitted
        euint64 executionPrice;            // Price at execution (if executed)
    }

    /// @notice Batch information for order processing
    struct BatchInfo {
        uint256 batchId;                   // Unique batch identifier
        uint256 startTime;                 // Batch start timestamp
        uint256 endTime;                   // Batch end timestamp
        uint256 orderCount;                // Number of orders in batch
        BatchStatus status;                // Current batch status
        uint256 executionTime;             // When batch was executed
        uint256 executedOrders;            // Number of successfully executed orders
        uint256[] orderIds;                // Array of order IDs in this batch
    }

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Submit a confidential order to the dark pool
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param encryptedAmountIn Encrypted input amount
     * @param encryptedMinAmountOut Encrypted minimum output amount
     * @param encryptedMaxSlippage Encrypted maximum slippage tolerance
     * @param deadline Order expiration timestamp
     * @return orderId The unique order identifier
     */
    function submitOrder(
        address tokenIn,
        address tokenOut,
        euint64 encryptedAmountIn,
        euint64 encryptedMinAmountOut,
        euint64 encryptedMaxSlippage,
        uint256 deadline
    ) external payable returns (uint256 orderId);

    /**
     * @notice Cancel a pending order
     * @param orderId The order ID to cancel
     */
    function cancelOrder(uint256 orderId) external;

    /**
     * @notice Execute the current batch if ready
     */
    function executeBatch() external;

    /**
     * @notice Add a supported trading pair
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     */
    function addTradingPair(address tokenA, address tokenB) external;

    /**
     * @notice Update protocol fee
     * @param newFeeBps New fee in basis points
     */
    function updateProtocolFee(uint256 newFeeBps) external;

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
     * @notice Get user's order history
     * @param user User address
     * @return orderIds Array of order IDs
     */
    function getUserOrders(address user) external view returns (uint256[] memory);

    /**
     * @notice Get batch information
     * @param batchId Batch ID
     * @return batch Batch information
     */
    function getBatch(uint256 batchId) external view returns (BatchInfo memory);

    /**
     * @notice Get current batch status
     * @return batchId Current batch ID
     * @return timeRemaining Time remaining in current batch
     * @return orderCount Number of orders in current batch
     */
    function getCurrentBatchStatus() external view returns (
        uint256 batchId,
        uint256 timeRemaining,
        uint256 orderCount
    );
}
