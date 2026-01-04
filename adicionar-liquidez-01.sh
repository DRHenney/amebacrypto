#!/bin/bash

# Script para adicionar liquidez na pool
# 100 USDC (6 decimais) = 100000000
# 0.1 WETH (18 decimais) = 100000000000000000

cd "$(dirname "$0")"
source .env

echo "🔄 Adicionando liquidez na pool..."

# Set liquidity amounts
export LIQUIDITY_TOKEN0_AMOUNT=100000000  # 100 USDC (6 decimais)
export LIQUIDITY_TOKEN1_AMOUNT=100000000000000000  # 0.1 WETH (18 decimais)

/home/derek/.foundry/versions/stable/forge script script/AddLiquidity.s.sol:AddLiquidity \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Liquidez adicionada!"


