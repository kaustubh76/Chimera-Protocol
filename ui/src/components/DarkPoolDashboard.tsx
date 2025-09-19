'use client'

import { useReadContract, useAccount } from 'wagmi'
import { CONTRACT_ADDRESSES, DARK_POOL_ENGINE_ABI } from '@/config/contracts'
import { useEffect, useState } from 'react'

export function DarkPoolDashboard() {
  const { isConnected } = useAccount()
  const [currentTime, setCurrentTime] = useState(Date.now())

  // Read contract data
  const { data: batchInfo } = useReadContract({
    address: CONTRACT_ADDRESSES.DARK_POOL_ENGINE,
    abi: DARK_POOL_ENGINE_ABI,
    functionName: 'getCurrentBatchInfo',
  })

  const { data: batchWindow } = useReadContract({
    address: CONTRACT_ADDRESSES.DARK_POOL_ENGINE,
    abi: DARK_POOL_ENGINE_ABI,
    functionName: 'getBatchWindow',
  })

  const { data: minOrderValue } = useReadContract({
    address: CONTRACT_ADDRESSES.DARK_POOL_ENGINE,
    abi: DARK_POOL_ENGINE_ABI,
    functionName: 'getMinOrderValue',
  })

  const { data: protocolFee } = useReadContract({
    address: CONTRACT_ADDRESSES.DARK_POOL_ENGINE,
    abi: DARK_POOL_ENGINE_ABI,
    functionName: 'getProtocolFee',
  })

  // Update current time every second
  useEffect(() => {
    const interval = setInterval(() => setCurrentTime(Date.now()), 1000)
    return () => clearInterval(interval)
  }, [])

  const batchData = batchInfo ? {
    batchId: Number(batchInfo[0]),
    orderCount: Number(batchInfo[1]),
    timeRemaining: Number(batchInfo[2]),
    isSettling: Boolean(batchInfo[3])
  } : null

  const formatEther = (value: bigint | undefined) => {
    if (!value) return '0'
    return (Number(value) / 1e18).toFixed(4)
  }

  const formatBasisPoints = (value: bigint | undefined) => {
    if (!value) return '0'
    return (Number(value) / 100).toFixed(2)
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center space-y-4">
        <h1 className="text-3xl font-bold bg-gradient-to-r from-cyan-400 to-blue-400 bg-clip-text text-transparent">
          🌊 Dark Pool Engine
        </h1>
        <p className="text-gray-300 max-w-2xl mx-auto">
          MEV-resistant trading through encrypted batch auctions. Orders are collected privately 
          and matched using Fully Homomorphic Encryption to prevent front-running and sandwich attacks.
        </p>
      </div>

      {/* Live Status Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-cyan-300 font-medium">Current Batch</h3>
            <div className={`w-3 h-3 rounded-full ${batchData?.isSettling ? 'bg-orange-400 animate-pulse' : 'bg-green-400'}`}></div>
          </div>
          <div className="text-2xl font-bold text-white">
            #{batchData?.batchId || 0}
          </div>
          <div className="text-sm text-gray-400">
            {batchData?.isSettling ? 'Settling...' : 'Collecting Orders'}
          </div>
        </div>

        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-cyan-300 font-medium">Orders in Batch</h3>
            <span className="text-cyan-400">📊</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {batchData?.orderCount || 0}
          </div>
          <div className="text-sm text-gray-400">Encrypted orders</div>
        </div>

        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-cyan-300 font-medium">Time Remaining</h3>
            <span className="text-cyan-400">⏰</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {batchData?.timeRemaining || 0}s
          </div>
          <div className="text-sm text-gray-400">Until next batch</div>
        </div>

        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-cyan-300 font-medium">Batch Window</h3>
            <span className="text-cyan-400">📅</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {batchWindow ? Number(batchWindow) : 300}s
          </div>
          <div className="text-sm text-gray-400">5 minute batches</div>
        </div>
      </div>

      {/* Configuration Panel */}
      <div className="grid md:grid-cols-2 gap-6">
        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">⚙️</span>
            Pool Configuration
          </h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-300">Min Order Value</span>
              <span className="text-white font-mono">
                {formatEther(minOrderValue)} ETH
              </span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-300">Protocol Fee</span>
              <span className="text-white font-mono">
                {formatBasisPoints(protocolFee)}%
              </span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-300">MEV Protection</span>
              <span className="text-green-400 font-medium">Active</span>
            </div>
            <div className="flex justify-between items-center py-2">
              <span className="text-gray-300">FHE Encryption</span>
              <span className="text-green-400 font-medium">Enabled</span>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">🔒</span>
            Privacy Features
          </h3>
          <div className="space-y-4">
            <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-3">
              <div className="text-green-400 font-medium mb-1">Order Encryption</div>
              <div className="text-sm text-gray-300">
                All order details are encrypted using FHE before submission
              </div>
            </div>
            <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-3">
              <div className="text-blue-400 font-medium mb-1">Batch Matching</div>
              <div className="text-sm text-gray-300">
                Orders matched in batches to prevent MEV exploitation
              </div>
            </div>
            <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-3">
              <div className="text-purple-400 font-medium mb-1">Price Discovery</div>
              <div className="text-sm text-gray-300">
                Fair price discovery through encrypted auction mechanism
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Trading Interface */}
      <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">💹</span>
          Trading Interface
        </h3>
        {isConnected ? (
          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Trade Direction
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button className="bg-green-600/20 hover:bg-green-600/30 text-green-400 py-2 px-4 rounded-lg transition-colors">
                    Buy WETH
                  </button>
                  <button className="bg-red-600/20 hover:bg-red-600/30 text-red-400 py-2 px-4 rounded-lg transition-colors">
                    Sell WETH
                  </button>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Amount (ETH)
                </label>
                <input
                  type="number"
                  placeholder="0.0"
                  className="w-full bg-gray-900/50 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-400 focus:border-cyan-400 focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Limit Price (USDC)
                </label>
                <input
                  type="number"
                  placeholder="0.0"
                  className="w-full bg-gray-900/50 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-400 focus:border-cyan-400 focus:outline-none"
                />
              </div>
            </div>
            <div className="space-y-4">
              <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4">
                <div className="text-yellow-400 font-medium mb-2">Privacy Notice</div>
                <div className="text-sm text-gray-300 space-y-1">
                  <p>• Your order will be encrypted using FHE</p>
                  <p>• Order details remain private until execution</p>
                  <p>• Matching occurs in the next batch window</p>
                  <p>• MEV protection is automatically enabled</p>
                </div>
              </div>
              <button
                disabled
                className="w-full bg-gray-600/50 text-gray-400 py-3 px-4 rounded-lg cursor-not-allowed"
              >
                Demo Mode - Trading Disabled
              </button>
            </div>
          </div>
        ) : (
          <div className="text-center py-8">
            <div className="text-gray-400 mb-4">
              Connect your wallet to access the trading interface
            </div>
            <div className="text-sm text-gray-500">
              Experience encrypted order submission and MEV-resistant trading
            </div>
          </div>
        )}
      </div>

      {/* Technical Details */}
      <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">🔬</span>
          Technical Implementation
        </h3>
        <div className="grid md:grid-cols-3 gap-6">
          <div>
            <h4 className="text-cyan-300 font-medium mb-3">Encryption Layer</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                Fhenix CoFHE Integration
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                TFHE Order Encryption
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                Private Price Matching
              </li>
            </ul>
          </div>
          <div>
            <h4 className="text-cyan-300 font-medium mb-3">MEV Protection</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Batch Auction Mechanism
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Order Commitment Scheme
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Fair Price Discovery
              </li>
            </ul>
          </div>
          <div>
            <h4 className="text-cyan-300 font-medium mb-3">Smart Contract</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Gas Optimized
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Reentrancy Protected
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Production Ready
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
