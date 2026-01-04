#!/bin/bash
# Script para criar nova pool com o hook atualizado

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

echo "🆕 Criando Nova Pool com Hook Atualizado"
echo "=========================================="
echo ""
echo "📍 Configuração:"
echo "  PoolManager: $POOL_MANAGER"
echo "  Hook: $HOOK_ADDRESS"
echo "  Token0: $TOKEN0_ADDRESS"
echo "  Token1: $TOKEN1_ADDRESS"
echo ""

$FORGE_CMD script script/CreateNewPoolWithNewHook.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Nova pool criada e configurada!"

