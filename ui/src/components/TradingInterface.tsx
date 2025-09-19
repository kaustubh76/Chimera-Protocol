'use client'

import { useState } from 'react'
import { useAccount } from 'wagmi'

export function TradingInterface() {
  const { isConnected } = useAccount()
  const [selectedPair, setSelectedPair] = useState('WETH/USDC')
  const [orderType, setOrderType] = useState<'limit' | 'market'>('limit')
  const [tradeDirection, setTradeDirection] = useState<'buy' | 'sell'>('buy')

  const tradingPairs = [
    { symbol: 'WETH/USDC', price: '3,245.67', change: '+2.3%', volume: '1.2M' },
    { symbol: 'WBTC/USDC', price: '67,890.12', change: '+1.8%', volume: '890K' },
    { symbol: 'UNI/USDC', price: '12.45', change: '-0.5%', volume: '2.1M' },
    { symbol: 'LINK/USDC', price: '18.92', change: '+3.2%', volume: '750K' }
  ]

  const recentTrades = [
    { time: '14:32:15', pair: 'WETH/USDC', side: 'Buy', amount: '0.5', price: '3,245.67', status: 'Filled' },
    { time: '14:28:42', pair: 'WETH/USDC', side: 'Sell', amount: '0.3', price: '3,242.10', status: 'Filled' },
    { time: '14:25:18', pair: 'UNI/USDC', side: 'Buy', amount: '100', price: '12.48', status: 'Filled' },
    { time: '14:22:33', pair: 'WBTC/USDC', side: 'Buy', amount: '0.1', price: '67,850.00', status: 'Partial' }
  ]

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center space-y-4">
        <h1 className="text-3xl font-bold bg-gradient-to-r from-green-400 to-emerald-400 bg-clip-text text-transparent">
          📈 Advanced Trading Interface
        </h1>
        <p className="text-gray-300 max-w-2xl mx-auto">
          Professional trading interface with MEV protection, encrypted order routing, 
          and sophisticated execution algorithms designed for institutional-grade performance.
        </p>
      </div>

      <div className="grid lg:grid-cols-3 gap-8">
        {/* Trading Pairs */}
        <div className="bg-gray-800/50 border border-green-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">💱</span>
            Trading Pairs
          </h3>
          <div className="space-y-3">
            {tradingPairs.map((pair, index) => (
              <button
                key={index}
                onClick={() => setSelectedPair(pair.symbol)}
                className={`w-full p-4 rounded-lg border transition-all ${
                  selectedPair === pair.symbol
                    ? 'border-green-400 bg-green-400/10'
                    : 'border-gray-600 bg-gray-700/30 hover:border-gray-500'
                }`}
              >
                <div className="flex justify-between items-center">
                  <div className="text-left">
                    <div className="font-semibold text-white">{pair.symbol}</div>
                    <div className="text-sm text-gray-400">Vol: {pair.volume}</div>
                  </div>
                  <div className="text-right">
                    <div className="font-mono text-white">${pair.price}</div>
                    <div className={`text-sm ${
                      pair.change.startsWith('+') ? 'text-green-400' : 'text-red-400'
                    }`}>
                      {pair.change}
                    </div>
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Trading Form */}
        <div className="bg-gray-800/50 border border-green-500/20 rounded-xl p-6">
          <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
            <span className="mr-2">🎯</span>
            Place Order
          </h3>
          
          {isConnected ? (
            <div className="space-y-4">
              {/* Trade Direction */}
              <div className="grid grid-cols-2 gap-2">
                <button
                  onClick={() => setTradeDirection('buy')}
                  className={`py-3 px-4 rounded-lg font-medium transition-colors ${
                    tradeDirection === 'buy'
                      ? 'bg-green-600 text-white'
                      : 'bg-green-600/20 text-green-400 hover:bg-green-600/30'
                  }`}
                >
                  Buy {selectedPair.split('/')[0]}
                </button>
                <button
                  onClick={() => setTradeDirection('sell')}
                  className={`py-3 px-4 rounded-lg font-medium transition-colors ${
                    tradeDirection === 'sell'
                      ? 'bg-red-600 text-white'
                      : 'bg-red-600/20 text-red-400 hover:bg-red-600/30'
                  }`}
                >
                  Sell {selectedPair.split('/')[0]}
                </button>
              </div>

              {/* Order Type */}
              <div className="grid grid-cols-2 gap-2">
                <button
                  onClick={() => setOrderType('market')}
                  className={`py-2 px-4 rounded-lg text-sm transition-colors ${
                    orderType === 'market'
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                  }`}
                >
                  Market
                </button>
                <button
                  onClick={() => setOrderType('limit')}
                  className={`py-2 px-4 rounded-lg text-sm transition-colors ${
                    orderType === 'limit'
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                  }`}
                >
                  Limit
                </button>
              </div>

              {/* Amount Input */}
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Amount ({selectedPair.split('/')[0]})
                </label>
                <input
                  type="number"
                  placeholder="0.0"
                  className="w-full bg-gray-900/50 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-400 focus:border-green-400 focus:outline-none"
                />
              </div>

              {/* Price Input (for limit orders) */}
              {orderType === 'limit' && (
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Price ({selectedPair.split('/')[1]})
                  </label>
                  <input
                    type="number"
                    placeholder="0.0"
                    className="w-full bg-gray-900/50 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-400 focus:border-green-400 focus:outline-none"
                  />
                </div>
              )}

              {/* Order Summary */}
              <div className="bg-gray-900/50 rounded-lg p-4 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Order Type:</span>
                  <span className="text-white capitalize">{orderType}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">MEV Protection:</span>
                  <span className="text-green-400">Enabled</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Privacy:</span>
                  <span className="text-blue-400">FHE Encrypted</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Estimated Fee:</span>
                  <span className="text-white">0.3%</span>
                </div>
              </div>

              <button
                disabled
                className="w-full bg-gray-600/50 text-gray-400 py-3 px-4 rounded-lg cursor-not-allowed"
              >
                Demo Mode - Trading Disabled
              </button>
            </div>
          ) : (
            <div className="text-center py-8">
              <div className="text-gray-400 mb-4">
                Connect your wallet to start trading
              </div>
              <div className="text-sm text-gray-500">
                Experience MEV-resistant trading with full privacy protection
              </div>
            </div>
          )}
        </div>

        {/* Order Book & Recent Trades */}
        <div className="space-y-6">
          {/* Mini Order Book */}
          <div className="bg-gray-800/50 border border-green-500/20 rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
              <span className="mr-2">📊</span>
              Order Book ({selectedPair})
            </h3>
            <div className="space-y-2">
              <div className="text-xs text-gray-400 grid grid-cols-3 gap-2">
                <span>Price</span>
                <span className="text-right">Amount</span>
                <span className="text-right">Total</span>
              </div>
              
              {/* Asks */}
              <div className="space-y-1">
                {[
                  { price: '3,248.50', amount: '2.5', total: '8,121.25' },
                  { price: '3,247.80', amount: '1.8', total: '5,846.04' },
                  { price: '3,246.90', amount: '3.2', total: '10,390.08' }
                ].map((order, index) => (
                  <div key={index} className="text-xs grid grid-cols-3 gap-2 text-red-400">
                    <span>${order.price}</span>
                    <span className="text-right">{order.amount}</span>
                    <span className="text-right">${order.total}</span>
                  </div>
                ))}
              </div>

              <div className="text-center py-2 text-white font-mono text-lg">
                $3,245.67
              </div>

              {/* Bids */}
              <div className="space-y-1">
                {[
                  { price: '3,244.20', amount: '1.5', total: '4,866.30' },
                  { price: '3,243.10', amount: '2.8', total: '9,080.68' },
                  { price: '3,242.00', amount: '0.9', total: '2,917.80' }
                ].map((order, index) => (
                  <div key={index} className="text-xs grid grid-cols-3 gap-2 text-green-400">
                    <span>${order.price}</span>
                    <span className="text-right">{order.amount}</span>
                    <span className="text-right">${order.total}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Recent Trades */}
          <div className="bg-gray-800/50 border border-green-500/20 rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
              <span className="mr-2">📈</span>
              Recent Trades
            </h3>
            <div className="space-y-2">
              <div className="text-xs text-gray-400 grid grid-cols-5 gap-2">
                <span>Time</span>
                <span>Side</span>
                <span>Amount</span>
                <span>Price</span>
                <span>Status</span>
              </div>
              {recentTrades.map((trade, index) => (
                <div key={index} className="text-xs grid grid-cols-5 gap-2">
                  <span className="text-gray-300">{trade.time}</span>
                  <span className={trade.side === 'Buy' ? 'text-green-400' : 'text-red-400'}>
                    {trade.side}
                  </span>
                  <span className="text-gray-300">{trade.amount}</span>
                  <span className="text-gray-300">${trade.price}</span>
                  <span className={`${
                    trade.status === 'Filled' ? 'text-green-400' : 'text-yellow-400'
                  }`}>
                    {trade.status}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Trading Features */}
      <div className="bg-gray-800/50 border border-green-500/20 rounded-xl p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center">
          <span className="mr-2">🛡️</span>
          Advanced Trading Features
        </h3>
        <div className="grid md:grid-cols-3 gap-6">
          <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4">
            <h4 className="text-blue-400 font-medium mb-2">MEV Protection</h4>
            <ul className="text-sm text-gray-300 space-y-1">
              <li>• Batch auction mechanism</li>
              <li>• Order encryption until execution</li>
              <li>• Fair price discovery</li>
              <li>• Front-running prevention</li>
            </ul>
          </div>
          <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-4">
            <h4 className="text-purple-400 font-medium mb-2">Privacy Features</h4>
            <ul className="text-sm text-gray-300 space-y-1">
              <li>• FHE order encryption</li>
              <li>• Private order matching</li>
              <li>• Confidential trade sizes</li>
              <li>• Anonymous execution</li>
            </ul>
          </div>
          <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-4">
            <h4 className="text-green-400 font-medium mb-2">Execution Quality</h4>
            <ul className="text-sm text-gray-300 space-y-1">
              <li>• Optimal price execution</li>
              <li>• Low slippage trading</li>
              <li>• Deep liquidity access</li>
              <li>• Smart order routing</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
