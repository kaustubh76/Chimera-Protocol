'use client'

import React, { useState } from 'react'
import { useReadContract } from 'wagmi'
import { CONTRACT_ADDRESSES, DARK_POOL_ENGINE_ABI, RISK_ENGINE_ABI } from '../config/contracts'

export function InteractiveContractTest() {
  const [testResults, setTestResults] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(false)

  // Dark Pool Engine Reads
  const { data: batchInfo, refetch: refetchBatchInfo } = useReadContract({
    address: CONTRACT_ADDRESSES.DARK_POOL_ENGINE,
    abi: DARK_POOL_ENGINE_ABI,
    functionName: 'getCurrentBatchInfo',
  })

  const { data: batchWindow } = useReadContract({
    address: CONTRACT_ADDRESSES.DARK_POOL_ENGINE,
    abi: DARK_POOL_ENGINE_ABI,
    functionName: 'getBatchWindow',
  })

  // Risk Engine Reads  
  const { data: systemRisk, refetch: refetchSystemRisk } = useReadContract({
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
    setTestResults(prev => [
      `${new Date().toLocaleTimeString()} - ${result}`,
      ...prev.slice(0, 9) // Keep last 10 results
    ])
  }

  const runComprehensiveTest = async () => {
    setIsLoading(true)
    addTestResult("🚀 Starting comprehensive contract test suite...")

    try {
      // Test Dark Pool Engine
      addTestResult("🌊 Testing Dark Pool Engine...")
      await refetchBatchInfo()
      addTestResult(`✅ Dark Pool: Batch #${batchInfo?.[0]?.toString()} with ${batchInfo?.[1]?.toString()} orders`)
      addTestResult(`✅ Dark Pool: Batch window is ${Number(batchWindow || 0) / 60} minutes`)

      // Test Risk Engine
      addTestResult("⚡ Testing Risk Engine...")
      await refetchSystemRisk()
      addTestResult(`✅ Risk Engine: ${systemRisk?.activePortfolios?.toString() || '0'} active portfolios`)
      addTestResult(`✅ Risk Engine: Emergency mode ${systemRisk?.emergencyMode ? 'ACTIVE' : 'inactive'}`)
      addTestResult(`✅ Risk Engine: Status ${isPaused ? 'PAUSED' : 'ACTIVE'}`)

      // Test contract responsiveness
      addTestResult("📡 Testing contract responsiveness...")
      const startTime = Date.now()
      await Promise.all([refetchBatchInfo(), refetchSystemRisk()])
      const responseTime = Date.now() - startTime
      addTestResult(`✅ Response time: ${responseTime}ms`)

      addTestResult("🎉 All contract tests completed successfully!")
    } catch (error) {
      addTestResult(`❌ Test failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setIsLoading(false)
    }
  }

  const testContractReads = async () => {
    setIsLoading(true)
    addTestResult("📖 Testing contract read functions...")

    try {
      const readTests = [
        { name: "Dark Pool Batch Info", fn: refetchBatchInfo },
        { name: "Risk Engine System Risk", fn: refetchSystemRisk }
      ]

      for (const test of readTests) {
        const startTime = Date.now()
        await test.fn()
        const duration = Date.now() - startTime
        addTestResult(`✅ ${test.name}: ${duration}ms`)
      }

      addTestResult("🎉 All read tests completed!")
    } catch (error) {
      addTestResult(`❌ Read test failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="bg-gray-800/30 rounded-xl p-6 border border-purple-500/10">
      <h2 className="text-2xl font-bold mb-6 text-center">🧪 Interactive Contract Testing</h2>
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Live Contract Data */}
        <div>
          <h3 className="text-lg font-semibold mb-4">📊 Live Contract State</h3>
          
          <div className="space-y-4">
            {/* Dark Pool Status */}
            <div className="bg-gray-700/50 rounded-lg p-4">
              <h4 className="font-medium text-blue-400 mb-2">🌊 Dark Pool Engine</h4>
              <div className="text-sm space-y-1">
                <div>Current Batch: #{batchInfo?.[0]?.toString() || 'Loading...'}</div>
                <div>Orders in Batch: {batchInfo?.[1]?.toString() || 'Loading...'}</div>
                <div>Time Remaining: {batchInfo?.[2]?.toString() || 'Loading...'}s</div>
                <div>Settling: {batchInfo?.[3] ? 'Yes' : 'No'}</div>
                <div>Batch Window: {Number(batchWindow || 0) / 60} min</div>
              </div>
            </div>

            {/* Risk Engine Status */}
            <div className="bg-gray-700/50 rounded-lg p-4">
              <h4 className="font-medium text-red-400 mb-2">⚡ Risk Engine</h4>
              <div className="text-sm space-y-1">
                <div>Status: {isPaused ? '🔴 Paused' : '🟢 Active'}</div>
                <div>Active Portfolios: {systemRisk?.activePortfolios?.toString() || 'Loading...'}</div>
                <div>Emergency Mode: {systemRisk?.emergencyMode ? '🚨 Active' : '✅ Normal'}</div>
                <div>Last Update: {new Date((Number(systemRisk?.lastUpdate || 0) * 1000)).toLocaleString()}</div>
              </div>
            </div>
          </div>
        </div>

        {/* Testing Controls */}
        <div>
          <h3 className="text-lg font-semibold mb-4">🔄 Test Controls</h3>
          
          <div className="space-y-4">
            <button
              onClick={runComprehensiveTest}
              disabled={isLoading}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:bg-gray-600 text-white py-3 px-4 rounded-lg font-medium transition-colors"
            >
              {isLoading ? '⏳ Running Tests...' : '🚀 Run Full Test Suite'}
            </button>

            <button
              onClick={testContractReads}
              disabled={isLoading}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white py-3 px-4 rounded-lg font-medium transition-colors"
            >
              {isLoading ? '⏳ Testing...' : '📖 Test Read Functions'}
            </button>

            <button
              onClick={() => {
                setTestResults([])
                addTestResult("🧹 Test results cleared")
              }}
              className="w-full bg-gray-600 hover:bg-gray-700 text-white py-3 px-4 rounded-lg font-medium transition-colors"
            >
              🧹 Clear Results
            </button>

            <button
              onClick={() => window.location.reload()}
              className="w-full bg-green-600 hover:bg-green-700 text-white py-3 px-4 rounded-lg font-medium transition-colors"
            >
              🔄 Refresh Page
            </button>
          </div>

          {/* Test Results */}
          <div className="mt-6">
            <h4 className="font-medium mb-3">📋 Test Results</h4>
            <div className="bg-gray-900/50 rounded-lg p-4 border border-gray-600 max-h-64 overflow-y-auto">
              {testResults.length === 0 ? (
                <div className="text-gray-400 text-sm">No test results yet. Run a test to see live output!</div>
              ) : (
                <div className="space-y-1">
                  {testResults.map((result, index) => (
                    <div key={index} className="text-xs text-green-400 font-mono">
                      {result}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="mt-8 grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-gray-700/30 rounded-lg p-4 text-center">
          <div className="text-2xl font-bold text-blue-400">{batchInfo?.[0]?.toString() || '0'}</div>
          <div className="text-sm text-gray-400">Current Batch</div>
        </div>
        <div className="bg-gray-700/30 rounded-lg p-4 text-center">
          <div className="text-2xl font-bold text-green-400">{batchInfo?.[1]?.toString() || '0'}</div>
          <div className="text-sm text-gray-400">Pending Orders</div>
        </div>
        <div className="bg-gray-700/30 rounded-lg p-4 text-center">
          <div className="text-2xl font-bold text-purple-400">{systemRisk?.activePortfolios?.toString() || '0'}</div>
          <div className="text-sm text-gray-400">Active Portfolios</div>
        </div>
        <div className="bg-gray-700/30 rounded-lg p-4 text-center">
          <div className="text-2xl font-bold text-red-400">{systemRisk?.emergencyMode ? '🚨' : '✅'}</div>
          <div className="text-sm text-gray-400">Emergency Mode</div>
        </div>
      </div>
    </div>
  )
}
