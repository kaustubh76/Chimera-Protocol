export const SEPOLIA_CHAIN_ID = 11155111;

export const CONTRACT_ADDRESSES = {
  DARK_POOL_ENGINE: "0x945d44fB15BB1e87f71D42560cd56e50B3174e87",
  STRATEGY_WEAVER: "0x7F30D44c6822903C44D90314afE8056BD1D20d1F", 
  CUSTOM_CURVE_HOOK: "0x6e18d1af6e9ab877047306b1e00db3749973ffcb",
  RISK_ENGINE: "0x23619431caB55Bf4C5fFa76AA5bD8591B5DE17DB"
} as const;

// Minimal ABIs for demonstration
export const DARK_POOL_ENGINE_ABI = [
  {
    "type": "function",
    "name": "getCurrentBatchInfo",
    "inputs": [],
    "outputs": [
      { "name": "batchId", "type": "uint256" },
      { "name": "orderCount", "type": "uint256" },
      { "name": "timeRemaining", "type": "uint256" },
      { "name": "isSettling", "type": "bool" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function", 
    "name": "getBatchWindow",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getMinOrderValue", 
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getProtocolFee",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  }
] as const;

export const STRATEGY_WEAVER_ABI = [
  {
    "type": "function",
    "name": "name",
    "inputs": [],
    "outputs": [{ "name": "", "type": "string" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "symbol", 
    "inputs": [],
    "outputs": [{ "name": "", "type": "string" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalSupply",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getManagementFee",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getPerformanceFee",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  }
] as const;

export const RISK_ENGINE_ABI = [
  {
    "type": "function",
    "name": "MAX_LEVERAGE",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "DEFAULT_VAR_CONFIDENCE",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "RISK_CHECK_INTERVAL",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "LIQUIDATION_THRESHOLD",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getSystemRisk",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "components": [
          { "name": "encryptedTotalTVL", "type": "uint256" },
          { "name": "encryptedSystemVaR", "type": "uint256" },
          { "name": "encryptedConcentrationRisk", "type": "uint256" },
          { "name": "activePortfolios", "type": "uint256" },
          { "name": "lastUpdate", "type": "uint256" },
          { "name": "emergencyMode", "type": "bool" }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
    "outputs": [{ "name": "", "type": "bool" }],
    "stateMutability": "view"
  }
] as const;
