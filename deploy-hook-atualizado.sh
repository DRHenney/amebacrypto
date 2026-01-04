#!/bin/bash
# Script para fazer deploy do hook atualizado (sem regra de 10x)
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

echo "🚀 Deploy do Hook Atualizado (sem regra de 10x)"
echo "================================================"
echo ""
echo "📍 Configuração:"
echo "  PoolManager: $POOL_MANAGER"
echo "  Token0: $TOKEN0_ADDRESS"
echo "  Token1: $TOKEN1_ADDRESS"
echo ""

echo "════════════════════════════════════════════════"
echo "  PASSO 1/5: Deploy do Hook Atualizado"
echo "════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/DeployAutoCompoundHook.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "⚠️  IMPORTANTE: Copie o Hook Address acima e atualize HOOK_ADDRESS no .env"
echo "   Depois execute: bash criar-pool-e-configurar.sh"
echo ""


