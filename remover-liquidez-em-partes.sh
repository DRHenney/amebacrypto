#!/bin/bash

# Script para remover liquidez em partes (para evitar SafeCastOverflow)
# Por padrão, usa o hook mais antigo: 0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540

cd "$(dirname "$0")"
source .env

echo "🔄 Removendo liquidez em partes (para evitar overflow)..."

# Se OLD_HOOK_ADDRESS não estiver definido, usa o padrão
if [ -z "$OLD_HOOK_ADDRESS" ]; then
    export OLD_HOOK_ADDRESS=0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540
    echo "Usando hook padrão: $OLD_HOOK_ADDRESS"
fi

/home/derek/.foundry/versions/stable/forge script script/RemoveLiquidityInParts.s.sol:RemoveLiquidityInParts \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Remoção de liquidez concluída!"

