#!/bin/bash

# Script para verificar estado completo da pool

cd "$(dirname "$0")" || exit 1
source .env 2>/dev/null || {
    echo "Erro: Arquivo .env nao encontrado!"
    exit 1
}

/home/derek/.foundry/versions/stable/forge script script/CheckPoolState.s.sol:CheckPoolState \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    -vvv

