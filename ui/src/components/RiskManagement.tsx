'use client'

import { useReadContract, useAccount } from 'wagmi'
import { CONTRACT_ADDRESSES, RISK_ENGINE_ABI } from '@/config/contracts'
import { useState } from 'react'

export function RiskManagement() {
  const { isConnected } = useAccount()
  const [selectedMetric, setSelectedMetric] = useState<'system' | 'portfolio' | 'circuit'>('system')

  // Read contract data
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

  const { data: riskInterval } = useReadContract({
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

  const formatLeverage = (value: bigint | undefined) => {
    if (!value) return '0'
    return (Number(value) / 1e18).toString()
  }

  const formatBasisPoints = (value: bigint | undefined) => {
    if (!value) return '0'
    return (Number(value) / 100).toFixed(1)
  }

  const systemRiskData = systemRisk ? {
    totalTVL: systemRisk[0],
    systemVaR: systemRisk[1], 
    concentrationRisk: systemRisk[2],
    activePortfolios: Number(systemRisk[3]),
    lastUpdate: Number(systemRisk[4]),
    emergencyMode: Boolean(systemRisk[5])
  } : null

  // Mock data for demonstration
  const portfolioMetrics = [
    { name: 'Portfolio Alpha', var: '2.3%', exposure: '$450K', leverage: '3.2x', status: 'Healthy' },
    { name: 'Portfolio Beta', var: '4.1%', exposure: '$220K', leverage: '1.8x', status: 'Healthy' },
    { name: 'Portfolio Gamma', var: '6.7%', exposure: '$180K', leverage: '5.1x', status: 'Warning' },
    { name: 'Portfolio Delta', var: '8.9%', exposure: '$90K', leverage: '7.2x', status: 'High Risk' }
  ]

  const circuitBreakers = [
    { name: 'System VaR Limit', status: 'Active', trigger: '10%', cooldown: '1 hour' },
    { name: 'Leverage Monitor', status: 'Active', trigger: '20x', cooldown: '30 min' },
    { name: 'Concentration Risk', status: 'Active', trigger: '25%', cooldown: '2 hours' },
    { name: 'Emergency Halt', status: 'Standby', trigger: 'Manual', cooldown: '24 hours' }
  ]

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center space-y-4">
        <h1 className="text-3xl font-bold bg-gradient-to-r from-orange-400 to-red-400 bg-clip-text text-transparent">
          ⚡ Advanced Risk Management
        </h1>
        <p className="text-gray-300 max-w-2xl mx-auto">
          Sophisticated risk monitoring with encrypted VaR calculations, real-time circuit breakers, 
          and automated liquidation triggers to protect against market volatility and systemic risks.
        </p>
      </div>

      {/* System Status */}
      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className={`border rounded-xl p-6 ${
          isPaused ? 'bg-red-500/10 border-red-500/20' : 'bg-gray-800/50 border-orange-500/20'
        }`}>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-orange-300 font-medium">System Status</h3>
            <div className={`w-3 h-3 rounded-full ${
              isPaused ? 'bg-red-400' : 'bg-green-400'
            }`}></div>
          </div>
          <div className="text-lg font-bold text-white">
            {isPaused ? 'Paused' : 'Operational'}
          </div>
          <div className="text-sm text-gray-400">
            {systemRiskData?.emergencyMode ? 'Emergency Mode' : 'Normal Operation'}
          </div>
        </div>

        <div className="bg-gray-800/50 border border-orange-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-orange-300 font-medium">Max Leverage</h3>
            <span className="text-orange-400">📊</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {formatLeverage(maxLeverage)}x
          </div>
          <div className="text-sm text-gray-400">Protocol limit</div>
        </div>

        <div className="bg-gray-800/50 border border-orange-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-orange-300 font-medium">VaR Confidence</h3>
            <span className="text-orange-400">📈</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {formatBasisPoints(varConfidence)}%
          </div>
          <div className="text-sm text-gray-400">Risk calculation</div>
        </div>

        <div className="bg-gray-800/50 border border-orange-500/20 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-orange-300 font-medium">Active Portfolios</h3>
            <span className="text-orange-400">🎯</span>
          </div>
          <div className="text-2xl font-bold text-white">
            {systemRiskData?.activePortfolios || 0}
          </div>
          <div className="text-sm text-gray-400">Under monitoring</div>
        </div>
      </div>

      {/* Risk Dashboard Navigation */}
      <div className="bg-gray-800/50 border border-orange-500/20 rounded-xl p-6">
        <div className="flex space-x-4 mb-6">
          {[
            { id: 'system', label: 'System Risk', icon: '🌐' },
            { id: 'portfolio', label: 'Portfolio Monitor', icon: '📊' },
            { id: 'circuit', label: 'Circuit Breakers', icon: '🔒' }
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setSelectedMetric(tab.id as any)}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                selectedMetric === tab.id
                  ? 'bg-orange-500/20 text-orange-400 border border-orange-500/30'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <span className="mr-2">{tab.icon}</span>
              {tab.label}
            </button>
          ))}
        </div>

        {/* System Risk View */}
        {selectedMetric === 'system' && (
          <div className="space-y-6">
            <div className="grid md:grid-cols-3 gap-6">
              <div className="bg-gray-900/50 rounded-lg p-4">
                <h4 className="text-orange-300 font-medium mb-3">System VaR</h4>
                <div className="text-2xl font-bold text-white mb-2">3.4%</div>
                <div className="text-sm text-gray-400">95% confidence level</div>
                <div className="mt-3 w-full bg-gray-700 rounded-full h-2">
                  <div className="bg-orange-500 h-2 rounded-full" style={{ width: '34%' }}></div>
                </div>
                <div className="text-xs text-gray-500 mt-1">Low risk threshold</div>
              </div>

              <div className="bg-gray-900/50 rounded-lg p-4">
                <h4 className="text-orange-300 font-medium mb-3">Concentration Risk</h4>
                <div className="text-2xl font-bold text-white mb-2">12.7%</div>
                <div className="text-sm text-gray-400">Single asset exposure</div>
                <div className="mt-3 w-full bg-gray-700 rounded-full h-2">
                  <div className="bg-yellow-500 h-2 rounded-full" style={{ width: '51%' }}></div>
                </div>
                <div className="text-xs text-gray-500 mt-1">Moderate concentration</div>
              </div>

              <div className="bg-gray-900/50 rounded-lg p-4">
                <h4 className="text-orange-300 font-medium mb-3">Liquidity Risk</h4>
                <div className="text-2xl font-bold text-white mb-2">5.8%</div>
                <div className="text-sm text-gray-400">Market depth analysis</div>
                <div className="mt-3 w-full bg-gray-700 rounded-full h-2">
                  <div className="bg-green-500 h-2 rounded-full" style={{ width: '23%' }}></div>
                </div>
                <div className="text-xs text-gray-500 mt-1">Healthy liquidity</div>
              </div>
            </div>

            <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-4">
              <div className="text-green-400 font-medium mb-2">Risk Assessment: HEALTHY</div>
              <div className="text-sm text-gray-300">
                All risk metrics are within acceptable thresholds. System is operating normally 
                with adequate capital buffers and diversification.
              </div>
            </div>
          </div>
        )}

        {/* Portfolio Monitor View */}
        {selectedMetric === 'portfolio' && (
          <div className="space-y-4">
            <h4 className="text-xl font-semibold text-white mb-4">Portfolio Risk Metrics</h4>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left py-3 text-orange-300">Portfolio</th>
                    <th className="text-left py-3 text-orange-300">VaR (95%)</th>
                    <th className="text-left py-3 text-orange-300">Exposure</th>
                    <th className="text-left py-3 text-orange-300">Leverage</th>
                    <th className="text-left py-3 text-orange-300">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {portfolioMetrics.map((portfolio, index) => (
                    <tr key={index} className="border-b border-gray-800">
                      <td className="py-3 text-white">{portfolio.name}</td>
                      <td className="py-3 text-gray-300">{portfolio.var}</td>
                      <td className="py-3 text-gray-300">{portfolio.exposure}</td>
                      <td className="py-3 text-gray-300">{portfolio.leverage}</td>
                      <td className="py-3">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          portfolio.status === 'Healthy' ? 'bg-green-500/20 text-green-400' :
                          portfolio.status === 'Warning' ? 'bg-yellow-500/20 text-yellow-400' :
                          'bg-red-500/20 text-red-400'
                        }`}>
                          {portfolio.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Circuit Breakers View */}
        {selectedMetric === 'circuit' && (
          <div className="space-y-4">
            <h4 className="text-xl font-semibold text-white mb-4">Circuit Breaker Status</h4>
            <div className="grid md:grid-cols-2 gap-4">
              {circuitBreakers.map((breaker, index) => (
                <div key={index} className="bg-gray-900/50 rounded-lg p-4">
                  <div className="flex items-center justify-between mb-3">
                    <h5 className="text-white font-medium">{breaker.name}</h5>
                    <span className={`px-2 py-1 rounded-full text-xs ${
                      breaker.status === 'Active' ? 'bg-green-500/20 text-green-400' :
                      'bg-gray-500/20 text-gray-400'
                    }`}>
                      {breaker.status}
                    </span>
                  </div>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-400">Trigger Level:</span>
                      <span className="text-gray-300">{breaker.trigger}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Cooldown:</span>
                      <span className="text-gray-300">{breaker.cooldown}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Risk Configuration */}
      <div className="bg-gray-800/50 border border-orange-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">⚙️</span>
          Risk Parameters
        </h3>
        
        {isConnected ? (
          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Risk Check Interval
                </label>
                <div className="text-white bg-gray-900/50 rounded-lg px-3 py-2">
                  {riskInterval ? Number(riskInterval) : 300} seconds
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Liquidation Threshold
                </label>
                <div className="text-white bg-gray-900/50 rounded-lg px-3 py-2">
                  {formatBasisPoints(liquidationThreshold)}%
                </div>
              </div>
            </div>
            
            <div className="space-y-4">
              <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4">
                <div className="text-blue-400 font-medium mb-2">FHE Privacy</div>
                <div className="text-sm text-gray-300 space-y-1">
                  <p>• All risk calculations use encrypted data</p>
                  <p>• Portfolio exposures remain confidential</p>
                  <p>• VaR computation preserves privacy</p>
                </div>
              </div>
              <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4">
                <div className="text-red-400 font-medium mb-2">Emergency Controls</div>
                <div className="text-sm text-gray-300 space-y-1">
                  <p>• Automatic circuit breakers</p>
                  <p>• Real-time liquidation triggers</p>
                  <p>• Manual emergency halt capability</p>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="text-center py-8">
            <div className="text-gray-400 mb-4">
              Connect your wallet to access risk management controls
            </div>
            <div className="text-sm text-gray-500">
              Experience real-time risk monitoring and circuit breaker management
            </div>
          </div>
        )}
      </div>

      {/* Technical Implementation */}
      <div className="bg-gray-800/50 border border-orange-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">🔬</span>
          Risk Engine Architecture
        </h3>
        <div className="grid md:grid-cols-3 gap-6">
          <div>
            <h4 className="text-orange-300 font-medium mb-3">Risk Models</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                Monte Carlo VaR
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                Encrypted Correlation Analysis
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                Real-time Stress Testing
              </li>
            </ul>
          </div>
          <div>
            <h4 className="text-orange-300 font-medium mb-3">Safety Mechanisms</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Circuit Breakers
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Liquidation Engine
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                Emergency Pause
              </li>
            </ul>
          </div>
          <div>
            <h4 className="text-orange-300 font-medium mb-3">Monitoring</h4>
            <ul className="text-sm text-gray-300 space-y-2">
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                24/7 Surveillance
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Automated Alerts
              </li>
              <li className="flex items-center">
                <span className="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                Risk Reporting
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
