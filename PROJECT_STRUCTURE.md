# Chimera Protocol Phase 2 - Project Structure

```
chimera-protocol-phase2/
├── README.md                           # Main project documentation
├── LICENSE                             # MIT License
├── foundry.toml                        # Foundry configuration
├── package.json                        # Node.js dependencies
├── .gitmodules                         # Git submodules configuration
├── .env.example                        # Environment variables template
│
├── contracts/                          # Smart contract source code
│   ├── darkpool/
│   │   └── DarkPoolEngine.sol         # MEV-resistant batch trading
│   ├── weaver/
│   │   └── StrategyWeaver.sol         # NFT-based portfolio management
│   ├── risk/
│   │   └── RiskEngine.sol             # Risk management and VaR calculations
│   ├── hooks/
│   │   └── CustomCurveHook.sol        # Uniswap V4 integration
│   ├── libraries/
│   │   ├── FHECurveEngine.sol         # FHE computation engine
│   │   └── OptimizedFHE.sol           # FHE optimization utilities
│   ├── interfaces/
│   │   ├── IDarkPoolEngine.sol        # Dark pool interface
│   │   ├── IStrategyWeaver.sol        # Strategy weaver interface
│   │   └── ICustomCurve.sol           # Custom curve interface
│   └── utils/                         # Utility contracts
│
├── script/                             # Deployment and interaction scripts
│   ├── ChimeraProtocolDeployment.s.sol # Main deployment script
│   ├── ContractInteractions.s.sol     # Contract interaction examples
│   └── SepoliaFunctionalTest.s.sol    # Sepolia testnet validation
│
├── test/                               # Test suite
│   ├── unit/                          # Unit tests
│   │   ├── DarkPoolEngine.t.sol
│   │   ├── StrategyWeaver.t.sol
│   │   ├── RiskEngine.t.sol
│   │   └── CustomCurveHook.t.sol
│   ├── integration/                   # Integration tests
│   │   └── ProtocolIntegration.t.sol
│   ├── fuzz/                          # Fuzz tests
│   │   └── FuzzTest.t.sol
│   └── invariant/                     # Invariant tests
│       └── InvariantTest.t.sol
│
├── lib/                                # External dependencies
│   ├── openzeppelin-contracts/        # Security-audited contracts
│   ├── v4-core/                       # Uniswap V4 core contracts
│   ├── v4-periphery/                  # Uniswap V4 periphery contracts
│   ├── solmate/                       # Gas-optimized contracts
│   └── cofhe-contracts/               # FHE contract libraries
│
├── docs/                               # Documentation
│   ├── README.md                      # Documentation index
│   ├── ARCHITECTURE.md                # Technical architecture
│   ├── DEPLOYMENT_GUIDE.md            # Deployment instructions
│   ├── DEVELOPER_GUIDE.md             # Development setup
│   ├── USER_GUIDE.md                  # User interaction guide
│   ├── SECURITY.md                    # Security considerations
│   ├── WHITEPAPER.md                  # Technical whitepaper
│   └── CUSTOM_CURVE_IMPLEMENTATION.md # Hook implementation details
│
└── ui/                                 # Interactive demo frontend
    ├── README.md                      # UI documentation
    ├── package.json                   # Frontend dependencies
    ├── next.config.ts                 # Next.js configuration
    ├── tailwind.config.js             # Tailwind CSS configuration
    ├── tsconfig.json                  # TypeScript configuration
    ├── .env.local                     # Environment variables
    │
    ├── src/
    │   ├── app/                       # Next.js app directory
    │   │   ├── layout.tsx             # Root layout
    │   │   ├── page.tsx               # Main dashboard
    │   │   └── providers.tsx          # Context providers
    │   │
    │   ├── components/                # React components
    │   │   ├── WalletConnect.tsx      # Wallet connection
    │   │   ├── ProtocolOverview.tsx   # Protocol dashboard
    │   │   └── InteractiveContractTest.tsx # Contract testing
    │   │
    │   └── config/                    # Configuration files
    │       ├── wagmi.ts               # Wagmi Web3 config
    │       └── contracts.ts           # Contract addresses/ABIs
    │
    └── public/                        # Static assets
        └── favicon.ico
```

## Key Components

### Smart Contracts
- **4 Core Contracts**: Dark Pool Engine, Strategy Weaver, Risk Engine, Custom Curve Hook
- **FHE Integration**: Fully homomorphic encryption for confidential computing
- **Uniswap V4 Hooks**: Advanced AMM functionality with custom curves
- **Security Features**: Multi-sig governance, circuit breakers, emergency stops

### Interactive UI Demo
- **Live Contract Data**: Real-time data from deployed Sepolia contracts
- **Wallet Integration**: MetaMask and other Web3 wallet support
- **Contract Testing**: Interactive testing interface for all functions
- **Responsive Design**: Modern UI with Tailwind CSS

### Documentation
- **Comprehensive Guides**: Architecture, deployment, development, and user guides
- **Security Documentation**: Audit status and security considerations
- **Technical Whitepaper**: Detailed protocol specification
- **Implementation Details**: Hook and FHE implementation specifics

### Testing Suite
- **Unit Tests**: Individual contract functionality
- **Integration Tests**: Cross-contract interactions
- **Fuzz Testing**: Property-based testing for edge cases
- **Invariant Testing**: Protocol-level invariant validation

## Deployment Status

### Sepolia Testnet (Live)
- ✅ Dark Pool Engine: `0x945d44fB15BB1e87f71D42560cd56e50B3174e87`
- ✅ Strategy Weaver: `0x7F30D44c6822903C44D90314afE8056BD1D20d1F`
- ✅ Risk Engine: `0x23619431caB55Bf4C5fFa76AA5bD8591B5DE17DB`
- ✅ Custom Curve Hook: `0x6e18d1af6e9ab877047306b1e00db3749973ffcb`

### UI Demo
- ✅ Interactive contract testing interface
- ✅ Live data from Sepolia contracts
- ✅ Real-time contract state monitoring
- ✅ Comprehensive testing capabilities

## Development Workflow

1. **Setup**: Clone repository, install dependencies
2. **Development**: Write contracts, tests, and documentation
3. **Testing**: Run comprehensive test suite
4. **Deployment**: Deploy to testnet/mainnet
5. **Verification**: Verify contracts on Etherscan
6. **Documentation**: Update documentation and guides

## Security Considerations

- **Internal Review**: ✅ Completed
- **External Audit**: Planned for mainnet deployment
- **Bug Bounty**: Coming soon
- **Emergency Procedures**: Documented in security guide
