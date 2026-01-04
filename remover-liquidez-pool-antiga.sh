#!/bin/bash

# Script para remover liquidez de uma pool antiga para obter 0.03 WETH
# Por padrão, usa o hook mais antigo: 0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540
# Para usar outro hook, defina OLD_HOOK_ADDRESS antes de executar:
# export OLD_HOOK_ADDRESS=0xEaF32b3657427a3796928035d6B2DBb28C355540

cd "$(dirname "$0")"
source .env

echo "🔄 Removendo liquidez de pool antiga para obter 0.03 WETH..."

# Se OLD_HOOK_ADDRESS não estiver definido, usa o padrão (hook mais antigo)
if [ -z "$OLD_HOOK_ADDRESS" ]; then
    export OLD_HOOK_ADDRESS=0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540
    echo "Usando hook padrão (mais antigo): $OLD_HOOK_ADDRESS"
else
    echo "Usando hook especificado: $OLD_HOOK_ADDRESS"
fi

/home/derek/.foundry/versions/stable/forge script script/RemoveLiquidityFromOldPool.s.sol:RemoveLiquidityFromOldPool \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Remoção de liquidez concluída!"

