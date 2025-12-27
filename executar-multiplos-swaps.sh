#!/bin/bash
cd /mnt/c/Users/derek/amebacrypto
source .env

FORGE_CMD="forge"
if ! command -v forge &> /dev/null; then
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        FORGE_CMD="$HOME/.foundry/bin/forge"
    elif [ -f "$HOME/.foundry/versions/stable/forge" ]; then
        FORGE_CMD="$HOME/.foundry/versions/stable/forge"
    fi
fi

# Default values
NUM_SWAPS=${NUM_SWAPS:-10}
SWAP_AMOUNT=${SWAP_WETH_AMOUNT:-1000000000000000}  # 0.001 WETH default
ALTERNATE=${ALTERNATE_DIRECTIONS:-true}

echo "🔄 Executando múltiplos swaps para gerar fees..."
echo "Hook: $HOOK_ADDRESS"
echo "Número de swaps: $NUM_SWAPS"
echo "Valor por swap: $SWAP_AMOUNT wei ($(echo "scale=6; $SWAP_AMOUNT / 1000000000000000000" | bc) WETH)"
echo "Direções alternadas: $ALTERNATE"
echo ""

# Export variables for forge script
export NUM_SWAPS
export SWAP_WETH_AMOUNT=$SWAP_AMOUNT
export ALTERNATE_DIRECTIONS=$ALTERNATE

$FORGE_CMD script script/MultipleSwaps.s.sol \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    -vvv

echo ""
echo "✅ Swaps executados!"
echo ""
echo "💡 Dica: Execute './verificar-estado-hook.sh' para ver o status atual das fees"
