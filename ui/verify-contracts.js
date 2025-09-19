#!/usr/bin/env node

const { ethers } = require('ethers');

// Contract addresses on Sepolia
const CONTRACT_ADDRESSES = {
  DARK_POOL_ENGINE: "0x945d44fB15BB1e87f71D42560cd56e50B3174e87",
  STRATEGY_WEAVER: "0x7F30D44c6822903C44D90314afE8056BD1D20d1F",
  CUSTOM_CURVE_HOOK: "0x6e18d1af6e9ab877047306b1e00db3749973ffcb",
  RISK_ENGINE: "0x23619431caB55Bf4C5fFa76AA5bD8591B5DE17DB"
};

const SEPOLIA_RPC_URL = "https://eth-sepolia.g.alchemy.com/v2/pFkOAygOyJ72KbT_I-LM0";

async function verifyContracts() {
  console.log("🔍 Verifying Chimera Protocol contracts on Sepolia...\n");
  
  const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
  
  for (const [name, address] of Object.entries(CONTRACT_ADDRESSES)) {
    try {
      console.log(`📋 Checking ${name}...`);
      console.log(`   Address: ${address}`);
      
      // Check if contract exists
      const code = await provider.getCode(address);
      if (code === "0x") {
        console.log(`   ❌ Status: No contract deployed at this address\n`);
        continue;
      }
      
      // Get basic contract info
      const balance = await provider.getBalance(address);
      const block = await provider.getBlockNumber();
      
      console.log(`   ✅ Status: Contract deployed`);
      console.log(`   💰 Balance: ${ethers.formatEther(balance)} ETH`);
      console.log(`   📦 Code size: ${(code.length - 2) / 2} bytes`);
      console.log(`   🔗 Explorer: https://sepolia.etherscan.io/address/${address}`);
      console.log("");
      
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}\n`);
    }
  }
  
  console.log("🎉 Contract verification complete!");
}

verifyContracts().catch(console.error);
