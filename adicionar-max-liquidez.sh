#!/bin/bash

# Script para adicionar o máximo de liquidez possível na pool

cd "$(dirname "$0")"
source .env

echo "🔄 Adicionando máximo de liquidez na pool..."

/home/derek/.foundry/versions/stable/forge script script/AddMaxLiquidity.s.sol:AddMaxLiquidity \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Liquidez máxima adicionada!"


