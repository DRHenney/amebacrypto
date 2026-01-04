#!/bin/bash

# Script para verificar liquidez em todas as pools conhecidas (hooks antigos e novos)

cd "$(dirname "$0")"
source .env

echo "🔍 Verificando liquidez em todas as pools conhecidas..."

/home/derek/.foundry/versions/stable/forge script script/CheckLiquidityInAllPools.s.sol:CheckLiquidityInAllPools \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Verificação concluída!"

