#!/bin/bash
# Script para migrar liquidez da pool antiga para a nova pool com novo hook

set -a
source .env 2>/dev/null || {
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
}
set +a

# Detectar caminho do forge
FORGE_CMD="forge"
if ! command -v forge &> /dev/null; then
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        FORGE_CMD="$HOME/.foundry/bin/forge"
    elif [ -f "$HOME/.foundry/versions/stable/forge" ]; then
        FORGE_CMD="$HOME/.foundry/versions/stable/forge"
    else
        echo "❌ Erro: forge não encontrado!"
        exit 1
    fi
fi

echo "🔄 Migrando Liquidez para Nova Pool"
echo "====================================="
echo ""
echo "📍 Configuração:"
echo "  PoolManager: $POOL_MANAGER"
echo "  Novo Hook: $HOOK_ADDRESS"
echo "  Pool Antiga Hook: 0xAc739f2F5c72C80a4491cf273308C3D94F00D540"
echo ""

$FORGE_CMD script script/MigrateLiquidityToNewHook.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Migração concluída!"

