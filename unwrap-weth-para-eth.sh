#!/bin/bash

# Script para fazer unwrap de todo WETH disponível para ETH

cd "$(dirname "$0")"
source .env

echo "🔄 Unwrapping todo WETH disponível para ETH..."

/home/derek/.foundry/versions/stable/forge script script/UnwrapWETH.s.sol:UnwrapWETH \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Unwrap concluído!"

