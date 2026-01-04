#!/bin/bash

# Script para remover liquidez usando PositionManager (queima de NFTs)

cd "$(dirname "$0")"
source .env

echo "🔄 Removendo liquidez usando PositionManager..."

/home/derek/.foundry/versions/stable/forge script script/RemoveLiquidityUsingPositionManager.s.sol:RemoveLiquidityUsingPositionManager \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Remoção de liquidez concluída!"

