#!/bin/bash

# Script para executar o keeper de compound automaticamente
# Este script verifica se pode executar compound e executa se as condições forem atendidas

cd "$(dirname "$0")" || exit 1
source .env 2>/dev/null || {
    echo "Erro: Arquivo .env nao encontrado!"
    exit 1
}

echo "=== Executando Auto Compound Keeper ==="
echo "Timestamp: $(date)"
echo ""

/home/derek/.foundry/versions/stable/forge script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    -vvv

echo ""
echo "=== Keeper execution finished ==="
echo "Timestamp: $(date)"

