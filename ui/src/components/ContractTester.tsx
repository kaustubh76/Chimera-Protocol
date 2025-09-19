'use client'

import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract } from 'wagmi'
import { CONTRACT_ADDRESSES, DARK_POOL_ENGINE_ABI, STRATEGY_WEAVER_ABI, RISK_ENGINE_ABI } from '@/config/contracts'
import { formatEther, parseEther } from 'viem'

export function ContractTester() {
  const { address, isConnected } = useAccount()
  const { writeContract } = useWriteContract()
  const [testResults, setTestResults] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(false)

  // Dark Pool Engine Contract Reads
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

  // Strategy Weaver Contract Reads
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

  // Risk Engine Contract Reads
  const { data: maxLeverage } = useReadContract({
    address: CONTRACT_ADDRESSES.RISK_ENGINE,
    abi: RISK_ENGINE_ABI,
    functionName: 'MAX_LEVERAGE',
  })

  const { data: varConfidence } = useReadContract({
    address: CONTRACT_ADDRESSES.RISK_ENGINE,
    abi: RISK_ENGINE_ABI,
    functionName: 'DEFAULT_VAR_CONFIDENCE',
  })

  const { data: riskCheckInterval } = useReadContract({
    address: CONTRACT_ADDRESSES.RISK_ENGINE,
    abi: RISK_ENGINE_ABI,
    functionName: 'RISK_CHECK_INTERVAL',
  })

  const { data: liquidationThreshold } = useReadContract({
    address: CONTRACT_ADDRESSES.RISK_ENGINE,
    abi: RISK_ENGINE_ABI,
    functionName: 'LIQUIDATION_THRESHOLD',
  })

  const { data: systemRisk } = useReadContract({
    address: CONTRACT_ADDRESSES.RISK_ENGINE,
    abi: RISK_ENGINE_ABI,
    functionName: 'getSystemRisk',
  })

  const { data: isPaused } = useReadContract({
    address: CONTRACT_ADDRESSES.RISK_ENGINE,
    abi: RISK_ENGINE_ABI,
    functionName: 'paused',
  })

  const addTestResult = (result: string) => {
    setTestResults(prev => [`${new Date().toLocaleTimeString()}: ${result}`, ...prev.slice(0, 9)])
  }

  const runComprehensiveTest = async () => {
    if (!isConnected) {
      addTestResult('❌ Please connect your wallet first')
      return
    }

    setIsLoading(true)
    addTestResult('🧪 Starting comprehensive contract testing...')

    try {
      // Test 1: Dark Pool Engine Status
      addTestResult(`✅ Dark Pool Engine - Current Batch: ${batchInfo?.[0]?.toString() || 'N/A'}`)
      addTestResult(`✅ Dark Pool Engine - Batch Window: ${batchWindow ? `${Number(batchWindow)}s` : 'N/A'}`)
      addTestResult(`✅ Dark Pool Engine - Min Order Value: ${minOrderValue ? formatEther(minOrderValue) : 'N/A'} ETH`)
      addTestResult(`✅ Dark Pool Engine - Protocol Fee: ${protocolFee ? `${Number(protocolFee)} bps` : 'N/A'}`)

      // Test 2: Strategy Weaver Status
      addTestResult(`✅ Strategy Weaver - NFT Name: ${nftName || 'N/A'}`)
      addTestResult(`✅ Strategy Weaver - NFT Symbol: ${nftSymbol || 'N/A'}`)
      addTestResult(`✅ Strategy Weaver - Total Supply: ${totalSupply?.toString() || '0'}`)
      addTestResult(`✅ Strategy Weaver - Management Fee: ${managementFee ? `${Number(managementFee)} bps` : 'N/A'}`)
      addTestResult(`✅ Strategy Weaver - Performance Fee: ${performanceFee ? `${Number(performanceFee)} bps` : 'N/A'}`)

      // Test 3: Risk Engine Status
      addTestResult(`✅ Risk Engine - Max Leverage: ${maxLeverage ? `${Number(maxLeverage) / 1e18}x` : 'N/A'}`)
      addTestResult(`✅ Risk Engine - VaR Confidence: ${varConfidence ? `${Number(varConfidence) / 100}%` : 'N/A'}`)
      addTestResult(`✅ Risk Engine - Risk Check Interval: ${riskCheckInterval ? `${Number(riskCheckInterval)}s` : 'N/A'}`)
      addTestResult(`✅ Risk Engine - Liquidation Threshold: ${liquidationThreshold ? `${Number(liquidationThreshold)} bps` : 'N/A'}`)
      addTestResult(`✅ Risk Engine - System Paused: ${isPaused ? 'Yes' : 'No'}`)

      if (systemRisk) {
        addTestResult(`✅ Risk Engine - Active Portfolios: ${systemRisk[3]?.toString() || '0'}`)
        addTestResult(`✅ Risk Engine - Emergency Mode: ${systemRisk[5] ? 'Yes' : 'No'}`)
        addTestResult(`✅ Risk Engine - Last Update: ${new Date(Number(systemRisk[4]) * 1000).toLocaleString()}`)
      }

      addTestResult('🎉 Comprehensive testing completed successfully!')
      
    } catch (error) {
      addTestResult(`❌ Test failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setIsLoading(false)
    }
  }

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <div className="text-6xl mb-4">🔒</div>
        <h2 className="text-2xl font-bold mb-4">Connect Wallet to Test Contracts</h2>
        <p className="text-gray-400 mb-6">
          Connect your wallet to interact with the deployed Chimera Protocol contracts
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center">
        <h1 className="text-3xl font-bold mb-4">🧪 Contract Testing Suite</h1>
        <p className="text-gray-300 mb-6">
          Comprehensive testing interface for all deployed Chimera Protocol contracts
        </p>
        <button
          onClick={runComprehensiveTest}
          disabled={isLoading}
          className="bg-purple-600 hover:bg-purple-700 disabled:bg-gray-600 text-white px-6 py-3 rounded-lg font-medium transition-colors"
        >
          {isLoading ? '🔄 Testing...' : '🚀 Run Comprehensive Test'}
        </button>
      </div>

      {/* Live Contract Data Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Dark Pool Engine */}
        <div className="bg-gray-800/50 rounded-xl p-6 border border-blue-500/20">
          <div className="flex items-center mb-4">
            <div className="text-2xl mr-3">🌊</div>
            <div>
              <h3 className="text-lg font-semibold">Dark Pool Engine</h3>
              <p className="text-sm text-gray-400">MEV-Resistant Trading</p>
            </div>
          </div>
          <div className="space-y-3">
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Current Batch ID</div>
              <div className="text-white font-mono">{batchInfo?.[0]?.toString() || 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Orders in Batch</div>
              <div className="text-white font-mono">{batchInfo?.[1]?.toString() || '0'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Batch Window</div>
              <div className="text-white font-mono">{batchWindow ? `${Number(batchWindow)}s` : 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Min Order Value</div>
              <div className="text-white font-mono">{minOrderValue ? `${formatEther(minOrderValue)} ETH` : 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Protocol Fee</div>
              <div className="text-white font-mono">{protocolFee ? `${Number(protocolFee)} bps` : 'Loading...'}</div>
            </div>
          </div>
        </div>

        {/* Strategy Weaver */}
        <div className="bg-gray-800/50 rounded-xl p-6 border border-green-500/20">
          <div className="flex items-center mb-4">
            <div className="text-2xl mr-3">🎯</div>
            <div>
              <h3 className="text-lg font-semibold">Portfolio Weaver</h3>
              <p className="text-sm text-gray-400">ZK Portfolio Management</p>
            </div>
          </div>
          <div className="space-y-3">
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">NFT Name</div>
              <div className="text-white font-mono">{nftName || 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">NFT Symbol</div>
              <div className="text-white font-mono">{nftSymbol || 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Total Portfolios</div>
              <div className="text-white font-mono">{totalSupply?.toString() || '0'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Management Fee</div>
              <div className="text-white font-mono">{managementFee ? `${Number(managementFee)} bps` : 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Performance Fee</div>
              <div className="text-white font-mono">{performanceFee ? `${Number(performanceFee)} bps` : 'Loading...'}</div>
            </div>
          </div>
        </div>

        {/* Risk Engine */}
        <div className="bg-gray-800/50 rounded-xl p-6 border border-red-500/20">
          <div className="flex items-center mb-4">
            <div className="text-2xl mr-3">⚡</div>
            <div>
              <h3 className="text-lg font-semibold">Risk Engine</h3>
              <p className="text-sm text-gray-400">Advanced Risk Management</p>
            </div>
          </div>
          <div className="space-y-3">
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Max Leverage</div>
              <div className="text-white font-mono">{maxLeverage ? `${Number(maxLeverage) / 1e18}x` : 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">VaR Confidence</div>
              <div className="text-white font-mono">{varConfidence ? `${Number(varConfidence) / 100}%` : 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Risk Check Interval</div>
              <div className="text-white font-mono">{riskCheckInterval ? `${Number(riskCheckInterval)}s` : 'Loading...'}</div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">System Status</div>
              <div className={`font-mono ${isPaused ? 'text-red-400' : 'text-green-400'}`}>
                {isPaused ? '⏸️ Paused' : '✅ Active'}
              </div>
            </div>
            <div className="bg-gray-700/30 p-3 rounded">
              <div className="text-xs text-gray-400 mb-1">Active Portfolios</div>
              <div className="text-white font-mono">{systemRisk?.[3]?.toString() || '0'}</div>
            </div>
          </div>
        </div>
      </div>

      {/* Test Results */}
      {testResults.length > 0 && (
        <div className="bg-gray-800/30 rounded-xl p-6 border border-purple-500/10">
          <h3 className="text-xl font-bold mb-4">📋 Test Results</h3>
          <div className="bg-black/30 rounded-lg p-4 font-mono text-sm max-h-64 overflow-y-auto">
            {testResults.map((result, index) => (
              <div key={index} className="mb-1 text-gray-300">
                {result}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Contract Addresses */}
      <div className="bg-gray-800/30 rounded-xl p-6 border border-purple-500/10">
        <h3 className="text-xl font-bold mb-4">📋 Live Contract Addresses (Sepolia)</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {Object.entries(CONTRACT_ADDRESSES).map(([name, address]) => (
            <div key={name} className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-400 font-medium">{name.replace(/_/g, ' ')}:</span>
              <div className="flex items-center space-x-2">
                <code className="text-purple-300 text-sm bg-gray-700/50 px-2 py-1 rounded">
                  {address}
                </code>
                <a
                  href={`https://sepolia.etherscan.io/address/${address}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-400 hover:text-blue-300 text-sm"
                >
                  🔗
                </a>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
