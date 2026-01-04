#!/bin/bash
# Script para configurar CompoundHelper no hook

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

echo "🔧 Configurando CompoundHelper no Hook"
echo "========================================"
echo ""
echo "📍 Endereços:"
echo "  Hook: $HOOK_ADDRESS"
echo "  PoolManager: $POOL_MANAGER"
echo ""

$FORGE_CMD script script/ConfigureCompoundHelper.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Configuração concluída!"

