'use client'

import { useReadContract, useAccount } from 'wagmi'
import { CONTRACT_ADDRESSES, STRATEGY_WEAVER_ABI } from '@/config/contracts'
import { useState } from 'react'

export function PortfolioWeaver() {
  const { isConnected } = useAccount()
  const [selectedPortfolio, setSelectedPortfolio] = useState<'balanced' | 'growth' | 'defensive'>('balanced')

  // Read contract data
  const { data: nftName } = useReadContract({
    address: CONTRACT_ADDRESSES.STRATEGY_WEAVER,
    abi: STRATEGY_WEAVER_ABI,
    functionName: 'name',
  })

  const { data: nftSymbol } = useReadContract({
    address: CONTRACT_ADDRESSES.STRATEGY_WEAVER,
    abi: STRATEGY_WEAVER_ABI,
    functionName: 'symbol',
  })

  const { data: totalSupply } = useReadContract({
    address: CONTRACT_ADDRESSES.STRATEGY_WEAVER,
    abi: STRATEGY_WEAVER_ABI,
    functionName: 'totalSupply',
  })

  const { data: managementFee } = useReadContract({
    address: CONTRACT_ADDRESSES.STRATEGY_WEAVER,
    abi: STRATEGY_WEAVER_ABI,
    functionName: 'getManagementFee',
  })

  const { data: performanceFee } = useReadContract({
    address: CONTRACT_ADDRESSES.STRATEGY_WEAVER,
    abi: STRATEGY_WEAVER_ABI,
    functionName: 'getPerformanceFee',
  })

  const portfolioTemplates = {
    balanced: {
      name: 'Balanced Growth',
      description: 'Diversified portfolio with moderate risk',
      allocation: [
        { asset: 'WETH', weight: 40, color: 'bg-blue-500' },
        { asset: 'WBTC', weight: 25, color: 'bg-orange-500' },
        { asset: 'USDC', weight: 20, color: 'bg-green-500' },
        { asset: 'UNI', weight: 15, color: 'bg-purple-500' }
      ],
      riskLevel: 'Medium',
      expectedAPY: '12-18%'
    },
    growth: {
      name: 'High Growth',
      description: 'Aggressive portfolio targeting maximum returns',
      allocation: [
        { asset: 'WETH', weight: 50, color: 'bg-blue-500' },
        { asset: 'WBTC', weight: 30, color: 'bg-orange-500' },
        { asset: 'UNI', weight: 20, color: 'bg-purple-500' }
      ],
      riskLevel: 'High',
      expectedAPY: '20-35%'
    },
    defensive: {
      name: 'Capital Preservation',
      description: 'Conservative portfolio focusing on stability',
      allocation: [
        { asset: 'USDC', weight: 50, color: 'bg-green-500' },
        { asset: 'WETH', weight: 30, color: 'bg-blue-500' },
        { asset: 'WBTC', weight: 20, color: 'bg-orange-500' }
      ],
      riskLevel: 'Low',
      expectedAPY: '5-8%'
    }
  }

  const formatBasisPoints = (value: bigint | undefined) => {
    if (!value) return '0'
    return (Number(value) / 100).toFixed(2)
  }

  const currentPortfolio = portfolioTemplates[selectedPortfolio]

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center space-y-4">
        <h1 className="text-3xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
          🎯 ZK-Portfolio Weaver
        </h1>
        <p className="text-gray-300 max-w-2xl mx-auto">
          Create and manage sophisticated investment portfolios as NFTs with confidential asset weights, 
          private rebalancing strategies, and encrypted performance tracking.
        </p>
      </div>

      {/* Contract Info Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-gray-800/50 border border-purple-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-purple-300 font-medium">NFT Collection</h3>
            <span className="text-purple-400">🎨</span>
          </div>
          <div className="text-lg font-bold text-white">
            {nftName || 'Chimera ZK-Portfolio'}
          </div>
          <div className="text-sm text-gray-400">
            Symbol: {nftSymbol || 'CZKP'}
          </div>
        </div>

        <div className="bg-gray-800/50 border border-purple-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-purple-300 font-medium">Total Portfolios</h3>
            <span className="text-purple-400">📊</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {totalSupply ? Number(totalSupply) : 0}
          </div>
          <div className="text-sm text-gray-400">Active NFTs</div>
        </div>

        <div className="bg-gray-800/50 border border-purple-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-purple-300 font-medium">Management Fee</h3>
            <span className="text-purple-400">💰</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {formatBasisPoints(managementFee)}%
          </div>
          <div className="text-sm text-gray-400">Annual fee</div>
        </div>

        <div className="bg-gray-800/50 border border-purple-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-purple-300 font-medium">Performance Fee</h3>
            <span className="text-purple-400">🚀</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {formatBasisPoints(performanceFee)}%
          </div>
          <div className="text-sm text-gray-400">On profits</div>
        </div>
      </div>

      {/* Portfolio Templates */}
      <div className="bg-gray-800/50 border border-purple-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-6 flex items-center">
          <span className="mr-2">📋</span>
          Portfolio Templates
        </h3>
        
        {/* Template Selector */}
        <div className="grid md:grid-cols-3 gap-4 mb-6">
          {Object.entries(portfolioTemplates).map(([key, template]) => (
            <button
              key={key}
              onClick={() => setSelectedPortfolio(key as any)}
              className={`p-4 rounded-lg border-2 transition-all ${
                selectedPortfolio === key
                  ? 'border-purple-400 bg-purple-400/10'
                  : 'border-gray-600 bg-gray-700/30 hover:border-gray-500'
              }`}
            >
              <div className="text-left">
                <div className="font-semibold text-white mb-1">{template.name}</div>
                <div className="text-sm text-gray-300 mb-2">{template.description}</div>
                <div className="flex justify-between items-center">
                  <span className={`text-xs px-2 py-1 rounded-full ${
                    template.riskLevel === 'High' ? 'bg-red-500/20 text-red-400' :
                    template.riskLevel === 'Medium' ? 'bg-yellow-500/20 text-yellow-400' :
                    'bg-green-500/20 text-green-400'
                  }`}>
                    {template.riskLevel} Risk
                  </span>
                  <span className="text-xs text-purple-300">{template.expectedAPY}</span>
                </div>
              </div>
            </button>
          ))}
        </div>

        {/* Selected Portfolio Details */}
        <div className="grid md:grid-cols-2 gap-6">
          <div>
            <h4 className="text-lg font-semibold text-white mb-4">Asset Allocation</h4>
            <div className="space-y-3">
              {currentPortfolio.allocation.map((asset, index) => (
                <div key={index} className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <div className={`w-4 h-4 rounded-full ${asset.color}`}></div>
                    <span className="text-white font-medium">{asset.asset}</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-24 bg-gray-700 rounded-full h-2">
                      <div 
                        className={`h-2 rounded-full ${asset.color}`}
                        style={{ width: `${asset.weight}%` }}
                      ></div>
                    </div>
                    <span className="text-gray-300 text-sm w-10">{asset.weight}%</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div>
            <h4 className="text-lg font-semibold text-white mb-4">Privacy Features</h4>
            <div className="space-y-3">
              <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-3">
                <div className="text-green-400 font-medium mb-1">Encrypted Weights</div>
                <div className="text-sm text-gray-300">
                  Asset allocations are encrypted using FHE
                </div>
              </div>
              <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-3">
                <div className="text-blue-400 font-medium mb-1">Private Rebalancing</div>
                <div className="text-sm text-gray-300">
                  Rebalancing strategies remain confidential
                </div>
              </div>
              <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-3">
                <div className="text-purple-400 font-medium mb-1">NFT Ownership</div>
                <div className="text-sm text-gray-300">
                  Portfolio represented as transferable NFT
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Portfolio Creation Interface */}
      <div className="bg-gray-800/50 border border-purple-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">🎨</span>
          Create New Portfolio
        </h3>
        
        {isConnected ? (
          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Portfolio Name
                </label>
                <input
                  type="text"
                  placeholder="My Investment Strategy"
                  className="w-full bg-gray-900/50 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-400 focus:border-purple-400 focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Initial Investment (ETH)
                </label>
                <input
                  type="number"
                  placeholder="1.0"
                  className="w-full bg-gray-900/50 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-400 focus:border-purple-400 focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Rebalancing Frequency
                </label>
                <select className="w-full bg-gray-900/50 border border-gray-600 rounded-lg px-3 py-2 text-white focus:border-purple-400 focus:outline-none">
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                  <option value="quarterly">Quarterly</option>
                  <option value="manual">Manual Only</option>
                </select>
              </div>
            </div>
            
            <div className="space-y-4">
              <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4">
                <div className="text-yellow-400 font-medium mb-2">Portfolio Features</div>
                <div className="text-sm text-gray-300 space-y-1">
                  <p>• Encrypted asset weights and strategies</p>
                  <p>• Automatic rebalancing with private execution</p>
                  <p>• NFT-based ownership and transferability</p>
                  <p>• Gas-optimized confidential operations</p>
                </div>
              </div>
              <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4">
                <div className="text-blue-400 font-medium mb-2">Fee Structure</div>
                <div className="text-sm text-gray-300 space-y-1">
                  <p>• Management Fee: {formatBasisPoints(managementFee)}% annually</p>
                  <p>• Performance Fee: {formatBasisPoints(performanceFee)}% on profits</p>
                  <p>• No hidden fees or charges</p>
                </div>
              </div>
              <button
                disabled
                className="w-full bg-gray-600/50 text-gray-400 py-3 px-4 rounded-lg cursor-not-allowed"
              >
                Demo Mode - Creation Disabled
              </button>
            </div>
          </div>
        ) : (
          <div className="text-center py-8">
            <div className="text-gray-400 mb-4">
              Connect your wallet to create a new portfolio
            </div>
            <div className="text-sm text-gray-500">
              Experience encrypted portfolio management and NFT-based ownership
            </div>
          </div>
        )}
      </div>

      {/* Technical Implementation */}
      <div className="bg-gray-800/50 border border-purple-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">🔬</span>
          Technical Architecture
        </h3>
        <div className="grid md:grid-cols-3 gap-6">
          <div>
            <h4 className="text-purple-300 font-medium mb-3">Smart Contract</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                ERC-721 NFT Standard
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                FHE Integration
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                Reentrancy Protection
              </li>
            </ul>
          </div>
          <div>
            <h4 className="text-purple-300 font-medium mb-3">Privacy Layer</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Encrypted Asset Weights
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Private Strategies
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Confidential Rebalancing
              </li>
            </ul>
          </div>
          <div>
            <h4 className="text-purple-300 font-medium mb-3">Features</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Dynamic Allocation
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Performance Tracking
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Risk Management
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
