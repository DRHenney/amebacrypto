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

echo "🔄 Executando swap WETH -> USDC para gerar fees..."
echo "Hook: $HOOK_ADDRESS"
echo ""

$FORGE_CMD script script/SwapWETHForUSDC.s.sol --rpc-url "$SEPOLIA_RPC_URL" --broadcast -vvv

