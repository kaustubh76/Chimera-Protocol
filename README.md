# Chimera Protocol Phase 2

## 🚀 Next-Generation DeFi Infrastructure with Confidential Computing

[![Solidity](https://img.shields.io/badge/Solidity-^0.8.26-blue.svg)](https://soliditylang.org/)
[![Next.js](https://img.shields.io/badge/Next.js-15.5.3-black.svg)](https://nextjs.org/)
[![Wagmi](https://img.shields.io/badge/Wagmi-2.16.9-purple.svg)](https://wagmi.sh/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Live Demo](https://img.shields.io/badge/Live%20Demo-Sepolia-orange.svg)](https://sepolia.etherscan.io/)

## Overview

Chimera Protocol Phase 2 is a revolutionary DeFi infrastructure that combines Fully Homomorphic Encryption (FHE) with advanced trading mechanisms to provide:

- **🔒 Privacy-Preserving Trading**: FHE-powered confidential computing
- **🌊 MEV-Resistant Dark Pools**: Batch auction mechanisms with encrypted orders
- **🎯 Smart Portfolio Management**: NFT-based portfolios with confidential asset weights
- **⚡ Advanced Risk Management**: Real-time VaR calculations and circuit breakers
- **🔗 Uniswap V4 Integration**: Custom curve hooks for enhanced liquidity

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Dark Pool     │    │  Strategy       │    │   Risk Engine   │
│   Engine        │◄──►│  Weaver         │◄──►│                 │
│                 │    │                 │    │                 │
│ • Batch Trading │    │ • NFT Portfolios│    │ • VaR Calculation│
│ • MEV Protection│    │ • FHE Weights   │    │ • Circuit Breakers│
│ • FHE Orders    │    │ • Performance   │    │ • Risk Monitoring│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Custom Curve    │
                    │ Hook (Uniswap   │
                    │ V4 Integration) │
                    │                 │
                    │ • FHE Curves    │
                    │ • Dynamic Fees  │
                    │ • MEV Protection│
                    └─────────────────┘
```

## 🎯 Key Features

### 1. Dark Pool Engine
- **Batch Auction Trading**: Groups orders into time-based batches
- **MEV Protection**: Encrypted orders prevent frontrunning
- **Fair Price Discovery**: Uniform clearing price for all matched orders
- **Configurable Parameters**: Flexible batch windows and fee structures

### 2. Strategy Weaver
- **NFT-Based Portfolios**: Each portfolio is represented as an NFT
- **Confidential Weights**: Asset allocations protected by FHE
- **Performance Tracking**: On-chain performance metrics
- **Management & Performance Fees**: Configurable fee structures

### 3. Risk Engine
- **Real-time VaR Calculation**: Value-at-Risk monitoring using FHE
- **Circuit Breakers**: Automatic trading halts during extreme conditions
- **Portfolio Risk Assessment**: Individual and systemic risk monitoring
- **Emergency Controls**: Pause mechanisms for critical situations

### 4. Custom Curve Hook
- **Uniswap V4 Integration**: Native integration with Uniswap V4 protocol
- **FHE-Powered Curves**: Confidential pricing mechanisms
- **Dynamic Fee Adjustment**: Real-time fee optimization
- **MEV-Resistant AMM**: Protected automated market making

## 🛠 Technology Stack

### Smart Contracts
- **Solidity**: ^0.8.26
- **Foundry**: Development and testing framework
- **OpenZeppelin**: Security-audited contract libraries
- **FHE Libraries**: Confidential computing primitives

### Frontend (UI Demo)
- **Next.js**: 15.5.3 (React framework)
- **TypeScript**: Type-safe development
- **Tailwind CSS**: Utility-first styling
- **Wagmi**: Ethereum integration
- **Viem**: Low-level Ethereum interactions

### Infrastructure
- **Sepolia Testnet**: Live deployment environment
- **IPFS**: Decentralized metadata storage
- **The Graph**: Indexing and querying (future)

## 📋 Contract Addresses (Sepolia Testnet)

| Contract | Address | Etherscan |
|----------|---------|-----------|
| Dark Pool Engine | `0x945d44fB15BB1e87f71D42560cd56e50B3174e87` | [View](https://sepolia.etherscan.io/address/0x945d44fB15BB1e87f71D42560cd56e50B3174e87) |
| Strategy Weaver | `0x7F30D44c6822903C44D90314afE8056BD1D20d1F` | [View](https://sepolia.etherscan.io/address/0x7F30D44c6822903C44D90314afE8056BD1D20d1F) |
| Risk Engine | `0x23619431caB55Bf4C5fFa76AA5bD8591B5DE17DB` | [View](https://sepolia.etherscan.io/address/0x23619431caB55Bf4C5fFa76AA5bD8591B5DE17DB) |
| Custom Curve Hook | `0x6e18d1af6e9ab877047306b1e00db3749973ffcb` | [View](https://sepolia.etherscan.io/address/0x6e18d1af6e9ab877047306b1e00db3749973ffcb) |

## 🚀 Quick Start

### Prerequisites
- Node.js v18+ and npm
- Git
- A Web3 wallet (MetaMask recommended)
- Sepolia testnet ETH for testing

### 1. Clone the Repository
```bash
git clone <repository-url>
cd chimera-protocol-phase2
```

### 2. Install Dependencies
```bash
# Install Foundry dependencies
forge install

# Install UI dependencies
cd ui
npm install
```

### 3. Set Up Environment
```bash
# Copy environment template
cp ui/.env.example ui/.env.local

# Add your RPC URL to ui/.env.local
NEXT_PUBLIC_SEPOLIA_RPC_URL=your_sepolia_rpc_url_here
```

### 4. Run the UI Demo
```bash
cd ui
npm run dev
```

Visit `http://localhost:3000` to see the interactive demo.

## 📖 Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)**: Detailed technical architecture
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)**: Contract deployment instructions
- **[Developer Guide](docs/DEVELOPER_GUIDE.md)**: Development setup and workflows
- **[User Guide](docs/USER_GUIDE.md)**: End-user interaction guide
- **[Security](docs/SECURITY.md)**: Security considerations and audit status
- **[Whitepaper](docs/WHITEPAPER.md)**: Technical whitepaper and research

## 🧪 Testing

### Smart Contract Tests
```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/unit/DarkPoolEngine.t.sol
```

### UI Tests
```bash
cd ui
npm run test
```

## 🚀 Deployment

### Local Development
```bash
# Start local Anvil node
anvil

# Deploy contracts locally
forge script script/ChimeraProtocolDeployment.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment
```bash
# Deploy to Sepolia
forge script script/ChimeraProtocolDeployment.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🛡 Security

### Audit Status
- **Internal Security Review**: ✅ Completed
- **External Audit**: 🔄 Planned for mainnet deployment
- **Bug Bounty**: 🔄 Coming soon

### Security Features
- Multi-signature governance controls
- Time-locked administrative functions
- Circuit breakers and emergency stops
- Comprehensive access controls

## 🔗 Links

- **Live Demo**: [https://chimera-protocol-demo.vercel.app](https://chimera-protocol-demo.vercel.app)
- **Documentation**: [https://docs.chimera-protocol.io](https://docs.chimera-protocol.io)
- **Twitter**: [@ChimeraProtocol](https://twitter.com/ChimeraProtocol)
- **Discord**: [Join our community](https://discord.gg/chimera-protocol)

## 🙏 Acknowledgments

- OpenZeppelin for security-audited contract libraries
- Foundry team for excellent development tooling
- Uniswap team for V4 protocol innovation
- FHE research community for confidential computing advances

---

**Built with ❤️ by the Chimera Protocol Team**
