#!/bin/bash

# Chimera Protocol Phase 2 - Final Cleanup Script
# This script ensures the codebase is clean and ready for submission

echo "🚀 Chimera Protocol Phase 2 - Final Cleanup"
echo "=========================================="

# Navigate to project root
cd "$(dirname "$0")"

echo "📁 Cleaning build artifacts..."
# Remove any remaining build artifacts
find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".next" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "dist" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "build" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.log" -type f -delete 2>/dev/null || true
find . -name ".DS_Store" -type f -delete 2>/dev/null || true

# Remove Foundry build artifacts if they exist
rm -rf out/ cache/ cache_forge/ broadcast/ 2>/dev/null || true

echo "🧹 Cleaning temporary files..."
# Remove temporary files
find . -name "*.tmp" -type f -delete 2>/dev/null || true
find . -name "*.temp" -type f -delete 2>/dev/null || true
find . -name "*~" -type f -delete 2>/dev/null || true

echo "📋 Validating project structure..."
# Check for required files
required_files=(
    "README.md"
    "LICENSE"
    "foundry.toml"
    "PROJECT_STRUCTURE.md"
    "SUBMISSION_SUMMARY.md"
    "ui/package.json"
    "ui/README.md"
    "contracts/darkpool/DarkPoolEngine.sol"
    "contracts/weaver/StrategyWeaver.sol"
    "contracts/risk/RiskEngine.sol"
    "contracts/hooks/CustomCurveHook.sol"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -eq 0 ]]; then
    echo "✅ All required files present"
else
    echo "❌ Missing files:"
    printf '%s\n' "${missing_files[@]}"
    exit 1
fi

echo "📊 Project statistics:"
echo "  Smart contracts: $(find contracts -name "*.sol" | wc -l | tr -d ' ')"
echo "  Test files: $(find test -name "*.sol" | wc -l | tr -d ' ')"
echo "  Documentation files: $(find docs -name "*.md" | wc -l | tr -d ' ')"
echo "  Script files: $(find script -name "*.sol" | wc -l | tr -d ' ')"

echo ""
echo "🎉 Cleanup complete! Project ready for submission."
echo ""
echo "📋 Quick Start Commands:"
echo "  UI Demo:          cd ui && npm install && npm run dev"
echo "  Smart Contracts:  forge install && forge test"
echo "  Documentation:    open README.md"
echo ""
echo "🔗 Live Contracts on Sepolia:"
echo "  Dark Pool Engine:  0x945d44fB15BB1e87f71D42560cd56e50B3174e87"
echo "  Strategy Weaver:   0x7F30D44c6822903C44D90314afE8056BD1D20d1F"
echo "  Risk Engine:       0x23619431caB55Bf4C5fFa76AA5bD8591B5DE17DB"
echo "  Custom Curve Hook: 0x6e18d1af6e9ab877047306b1e00db3749973ffcb"
echo ""
echo "✨ Chimera Protocol Phase 2 - Ready for the future of DeFi! ✨"
