#!/bin/bash

# Script para calcular os saldos de tokens na pool

cd "$(dirname "$0")"
source .env

echo "🔍 Calculando saldos de tokens na pool..."

/home/derek/.foundry/versions/stable/forge script script/CalculatePoolBalances.s.sol:CalculatePoolBalances \
    --rpc-url "$SEPOLIA_RPC_URL" \
    -vvv

