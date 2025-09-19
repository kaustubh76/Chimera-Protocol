// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {RiskEngine} from "../contracts/risk/RiskEngine.sol";

/**
 * @title DeployRiskEngine
 * @notice Deploy RiskEngine to Sepolia testnet
 */
contract DeployRiskEngine is Script {
    
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
        console.log("=== DEPLOYING RISK ENGINE ===");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        
        vm.startBroadcast(privateKey);
        
        RiskEngine riskEngine = new RiskEngine(deployer);
        
        vm.stopBroadcast();
        
        console.log("RiskEngine deployed at:", address(riskEngine));
        console.log("Update your .env with:");
        console.log("RISK_ENGINE=", address(riskEngine));
    }
}
