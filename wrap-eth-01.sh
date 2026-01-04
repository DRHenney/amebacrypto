#!/bin/bash

# Script para fazer wrap de 0.1 ETH para WETH

cd "$(dirname "$0")"
source .env

echo "🔄 Wrapping ETH to WETH (90% do saldo disponível)..."

# Não definir WRAP_AMOUNT - o script usará 90% do saldo disponível
# export WRAP_AMOUNT=100000000000000000

/home/derek/.foundry/versions/stable/forge script script/WrapETH.s.sol:WrapETH \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Wrap concluído!"

