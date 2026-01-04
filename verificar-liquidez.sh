#!/bin/bash

# Script para verificar a liquidez atual da pool

cd "$(dirname "$0")"
source .env

echo "🔍 Verificando liquidez atual da pool..."

/home/derek/.foundry/versions/stable/forge script script/CheckPoolStatus.s.sol:CheckPoolStatus \
    --rpc-url "$SEPOLIA_RPC_URL" \
    -vvv

