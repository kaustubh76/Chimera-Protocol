# Chimera Protocol Phase 2 - UI Demo

## 🎯 Interactive Demo Overview

This UI demo provides a **fully functional interface** for interacting with the Chimera Protocol Phase 2 contracts deployed on Sepolia testnet. Unlike static demos, this interface connects to **real smart contracts** and displays **live data**.

## ✨ Features

### 🔗 **Live Contract Integration**
- **Real-time Data**: Displays actual contract state from Sepolia
- **Interactive Testing**: Execute contract functions directly from the UI
- **Transaction Support**: Submit transactions and track confirmations
- **Error Handling**: Graceful handling of network and contract errors

### 💼 **Wallet Integration**
- **Multiple Wallets**: MetaMask, WalletConnect, Coinbase Wallet
- **Network Detection**: Automatic Sepolia network detection
- **Account Management**: Connect/disconnect functionality
- **Transaction Signing**: Secure transaction signing flow

## 🚀 Quick Start

### Prerequisites
- Node.js v18+ and npm
- A Web3 wallet (MetaMask recommended)
- Sepolia testnet ETH for testing

### Installation & Setup
```bash
# Install dependencies
npm install

# Copy environment template (if needed)
cp .env.example .env.local

# Start development server
npm run dev
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
