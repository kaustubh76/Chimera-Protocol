import { createConfig, http } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { injected, metaMask } from 'wagmi/connectors'

// Get RPC URL from environment variables
const sepoliaRpcUrl = process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/pFkOAygOyJ72KbT_I-LM0'

export const config = createConfig({
  chains: [sepolia],
  connectors: [
    injected(),
    metaMask(),
  ],
  transports: {
    [sepolia.id]: http(sepoliaRpcUrl),
  },
  ssr: true, // Enable SSR support
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}
