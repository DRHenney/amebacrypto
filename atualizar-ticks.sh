#!/bin/bash
cd /mnt/c/Users/derek/amebacrypto
source .env

/home/derek/.foundry/versions/stable/forge script script/UpdateTickRange.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

