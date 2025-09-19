'use client'

import { useState } from 'react'

export function AnalyticsDashboard() {
  const [timeframe, setTimeframe] = useState<'1D' | '7D' | '30D' | '90D'>('7D')

  const protocolMetrics = [
    { label: 'Total Value Locked', value: '$2.4M', change: '+15.2%', trend: 'up' },
    { label: 'Daily Volume', value: '$450K', change: '+8.7%', trend: 'up' },
    { label: 'Active Users', value: '1,247', change: '+23.1%', trend: 'up' },
    { label: 'Transaction Count', value: '8,932', change: '+12.3%', trend: 'up' }
  ]

  const portfolioPerformance = [
    { name: 'Balanced Growth', apy: '14.2%', tvl: '$890K', risk: 'Medium', performance: 'good' },
    { name: 'High Growth', apy: '28.7%', tvl: '$450K', risk: 'High', performance: 'excellent' },
    { name: 'Conservative', apy: '6.8%', tvl: '$320K', risk: 'Low', performance: 'stable' },
    { name: 'DeFi Alpha', apy: '35.1%', tvl: '$180K', risk: 'Very High', performance: 'excellent' }
  ]

  const riskMetrics = {
    systemVaR: '3.4%',
    concentrationRisk: '12.7%',
    liquidityRisk: '5.8%',
    leverageUtilization: '68.2%'
  }

  const activityData = [
    { time: '00:00', volume: 45, trades: 12 },
    { time: '04:00', volume: 32, trades: 8 },
    { time: '08:00', volume: 78, trades: 23 },
    { time: '12:00', volume: 95, trades: 31 },
    { time: '16:00', volume: 112, trades: 28 },
    { time: '20:00', volume: 89, trades: 19 }
  ]

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center space-y-4">
        <h1 className="text-3xl font-bold bg-gradient-to-r from-cyan-400 to-purple-400 bg-clip-text text-transparent">
          📊 Protocol Analytics
        </h1>
        <p className="text-gray-300 max-w-2xl mx-auto">
          Comprehensive analytics dashboard providing real-time insights into protocol performance, 
          risk metrics, and user activity with privacy-preserving data visualization.
        </p>
      </div>

      {/* Key Metrics */}
      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
        {protocolMetrics.map((metric, index) => (
          <div key={index} className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-cyan-300 font-medium text-sm">{metric.label}</h3>
              <span className={`text-xs px-2 py-1 rounded-full ${
                metric.trend === 'up' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
              }`}>
                {metric.change}
              </span>
            </div>
            <div className="text-2xl font-bold text-white">{metric.value}</div>
          </div>
        ))}
      </div>

      {/* Time Range Selector */}
      <div className="flex justify-center">
        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-2">
          <div className="flex space-x-2">
            {(['1D', '7D', '30D', '90D'] as const).map((period) => (
              <button
                key={period}
                onClick={() => setTimeframe(period)}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  timeframe === period
                    ? 'bg-cyan-500 text-white'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                {period}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="grid lg:grid-cols-2 gap-8">
        {/* Protocol Activity Chart */}
        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">📈</span>
            Trading Activity ({timeframe})
          </h3>
          <div className="h-64 flex items-end justify-between space-x-2">
            {activityData.map((data, index) => (
              <div key={index} className="flex-1 flex flex-col items-center">
                <div className="w-full bg-gray-700 rounded-t-lg relative" style={{ height: '200px' }}>
                  <div 
                    className="absolute bottom-0 w-full bg-cyan-500 rounded-t-lg transition-all duration-500"
                    style={{ height: `${(data.volume / 120) * 100}%` }}
                  ></div>
                  <div 
                    className="absolute bottom-0 w-full bg-purple-500/60 rounded-t-lg transition-all duration-500"
                    style={{ height: `${(data.trades / 35) * 100}%` }}
                  ></div>
                </div>
                <div className="text-xs text-gray-400 mt-2">{data.time}</div>
              </div>
            ))}
          </div>
          <div className="flex justify-center space-x-4 mt-4">
            <div className="flex items-center">
              <div className="w-3 h-3 bg-cyan-500 rounded-full mr-2"></div>
              <span className="text-sm text-gray-300">Volume ($K)</span>
            </div>
            <div className="flex items-center">
              <div className="w-3 h-3 bg-purple-500 rounded-full mr-2"></div>
              <span className="text-sm text-gray-300">Trades</span>
            </div>
          </div>
        </div>

        {/* Risk Overview */}
        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">⚡</span>
            Risk Metrics Overview
          </h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-gray-300">System VaR (95%)</span>
              <div className="flex items-center space-x-2">
                <div className="w-24 bg-gray-700 rounded-full h-2">
                  <div className="bg-green-500 h-2 rounded-full" style={{ width: '34%' }}></div>
                </div>
                <span className="text-white font-mono text-sm">{riskMetrics.systemVaR}</span>
              </div>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-300">Concentration Risk</span>
              <div className="flex items-center space-x-2">
                <div className="w-24 bg-gray-700 rounded-full h-2">
                  <div className="bg-yellow-500 h-2 rounded-full" style={{ width: '51%' }}></div>
                </div>
                <span className="text-white font-mono text-sm">{riskMetrics.concentrationRisk}</span>
              </div>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-300">Liquidity Risk</span>
              <div className="flex items-center space-x-2">
                <div className="w-24 bg-gray-700 rounded-full h-2">
                  <div className="bg-blue-500 h-2 rounded-full" style={{ width: '23%' }}></div>
                </div>
                <span className="text-white font-mono text-sm">{riskMetrics.liquidityRisk}</span>
              </div>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-300">Leverage Utilization</span>
              <div className="flex items-center space-x-2">
                <div className="w-24 bg-gray-700 rounded-full h-2">
                  <div className="bg-orange-500 h-2 rounded-full" style={{ width: '68%' }}></div>
                </div>
                <span className="text-white font-mono text-sm">{riskMetrics.leverageUtilization}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Portfolio Performance */}
      <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">🎯</span>
          Portfolio Performance Analysis
        </h3>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-700">
                <th className="text-left py-3 text-cyan-300">Portfolio</th>
                <th className="text-left py-3 text-cyan-300">APY</th>
                <th className="text-left py-3 text-cyan-300">TVL</th>
                <th className="text-left py-3 text-cyan-300">Risk Level</th>
                <th className="text-left py-3 text-cyan-300">Performance</th>
              </tr>
            </thead>
            <tbody>
              {portfolioPerformance.map((portfolio, index) => (
                <tr key={index} className="border-b border-gray-800">
                  <td className="py-3 text-white font-medium">{portfolio.name}</td>
                  <td className="py-3 text-green-400 font-mono">{portfolio.apy}</td>
                  <td className="py-3 text-gray-300 font-mono">{portfolio.tvl}</td>
                  <td className="py-3">
                    <span className={`px-2 py-1 rounded-full text-xs ${
                      portfolio.risk === 'Low' ? 'bg-green-500/20 text-green-400' :
                      portfolio.risk === 'Medium' ? 'bg-yellow-500/20 text-yellow-400' :
                      portfolio.risk === 'High' ? 'bg-orange-500/20 text-orange-400' :
                      'bg-red-500/20 text-red-400'
                    }`}>
                      {portfolio.risk}
                    </span>
                  </td>
                  <td className="py-3">
                    <span className={`px-2 py-1 rounded-full text-xs ${
                      portfolio.performance === 'excellent' ? 'bg-green-500/20 text-green-400' :
                      portfolio.performance === 'good' ? 'bg-blue-500/20 text-blue-400' :
                      'bg-gray-500/20 text-gray-400'
                    }`}>
                      {portfolio.performance}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Privacy & Security Metrics */}
      <div className="grid md:grid-cols-2 gap-6">
        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">🔒</span>
            Privacy Metrics
          </h3>
          <div className="space-y-4">
            <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4">
              <div className="text-blue-400 font-medium mb-1">FHE Operations</div>
              <div className="text-2xl font-bold text-white mb-1">12,847</div>
              <div className="text-sm text-gray-400">Encrypted computations performed</div>
            </div>
            <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-4">
              <div className="text-purple-400 font-medium mb-1">Privacy Score</div>
              <div className="text-2xl font-bold text-white mb-1">98.7%</div>
              <div className="text-sm text-gray-400">Data confidentiality maintained</div>
            </div>
            <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-4">
              <div className="text-green-400 font-medium mb-1">MEV Protection</div>
              <div className="text-2xl font-bold text-white mb-1">$2.1M</div>
              <div className="text-sm text-gray-400">Value protected from MEV</div>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">🛡️</span>
            Security Status
          </h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-300">Smart Contract Security</span>
              <span className="text-green-400 font-medium">Verified ✓</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-300">FHE Implementation</span>
              <span className="text-green-400 font-medium">Active ✓</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-300">Circuit Breakers</span>
              <span className="text-green-400 font-medium">Operational ✓</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-700">
              <span className="text-gray-300">Risk Monitoring</span>
              <span className="text-green-400 font-medium">24/7 Active ✓</span>
            </div>
            <div className="flex justify-between items-center py-2">
              <span className="text-gray-300">Emergency Controls</span>
              <span className="text-green-400 font-medium">Ready ✓</span>
            </div>
          </div>
        </div>
      </div>

      {/* Data Export */}
      <div className="bg-gray-800/50 border border-cyan-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">📊</span>
          Data Export & Reports
        </h3>
        <div className="grid md:grid-cols-3 gap-4">
          <button
            disabled
            className="bg-gray-600/50 text-gray-400 py-3 px-4 rounded-lg cursor-not-allowed flex items-center justify-center"
          >
            📈 Performance Report
          </button>
          <button
            disabled
            className="bg-gray-600/50 text-gray-400 py-3 px-4 rounded-lg cursor-not-allowed flex items-center justify-center"
          >
            ⚡ Risk Analysis
          </button>
          <button
            disabled
            className="bg-gray-600/50 text-gray-400 py-3 px-4 rounded-lg cursor-not-allowed flex items-center justify-center"
          >
            🔒 Privacy Report
          </button>
        </div>
        <div className="text-center text-sm text-gray-500 mt-4">
          Export functionality available in production environment
        </div>
      </div>
    </div>
  )
}
