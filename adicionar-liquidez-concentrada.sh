#!/bin/bash

# Script para adicionar liquidez concentrada na pool
# Primeiro faz wrap de todo ETH para WETH, depois adiciona toda a liquidez
# CONCENTRATION_BPS: concentração em basis points (1000 = 10%, 2000 = 20%, etc.)
# Default: 1000 (10%)

cd "$(dirname "$0")"
source .env

# Set concentration (default: 10% = 1000 bps)
export CONCENTRATION_BPS=${CONCENTRATION_BPS:-1000}

echo "🔄 Passo 1: Convertendo todo ETH para WETH..."
export WRAP_ALL_ETH=true

/home/derek/.foundry/versions/stable/forge script script/WrapETH.s.sol:WrapETH \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ ETH convertido para WETH!"
echo ""
echo "🔄 Passo 2: Adicionando liquidez concentrada na pool..."
echo "Concentração: $CONCENTRATION_BPS bps ($((CONCENTRATION_BPS / 100))%)"

/home/derek/.foundry/versions/stable/forge script script/AddConcentratedLiquidity.s.sol:AddConcentratedLiquidity \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Liquidez concentrada adicionada!"
