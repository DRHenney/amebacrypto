#!/bin/bash

# Script para remover liquidez da pool para obter aproximadamente 0.03 WETH

cd "$(dirname "$0")"
source .env

echo "🔄 Removendo liquidez para obter 0.03 WETH..."

/home/derek/.foundry/versions/stable/forge script script/RemoveLiquidityForWETH.s.sol:RemoveLiquidityForWETH \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Remoção de liquidez concluída!"

