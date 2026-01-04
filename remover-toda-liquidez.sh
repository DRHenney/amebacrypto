#!/bin/bash

# Script para remover TODA a liquidez da pool

cd "$(dirname "$0")"
source .env

echo "🔄 Removendo TODA a liquidez da pool..."

/home/derek/.foundry/versions/stable/forge script script/RemoveAllLiquidity.s.sol:RemoveAllLiquidity \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Remoção de liquidez concluída!"

