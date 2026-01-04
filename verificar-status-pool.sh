#!/bin/bash

# Script para verificar status completo da pool e fees acumuladas

cd "$(dirname "$0")"
source .env

echo "🔍 Verificando status da pool e fees acumuladas..."
echo ""

/home/derek/.foundry/versions/stable/forge script script/CheckPoolStatus.s.sol:CheckPoolStatus \
    --rpc-url "$SEPOLIA_RPC_URL" \
    -vv

echo ""
echo "✅ Verificação concluída!"

