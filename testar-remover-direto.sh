#!/bin/bash

cd "$(dirname "$0")"
source .env

export OLD_HOOK_ADDRESS=0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540

/home/derek/.foundry/versions/stable/forge script script/RemoveLiquidityDirect.s.sol:RemoveLiquidityDirect \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    -vv

