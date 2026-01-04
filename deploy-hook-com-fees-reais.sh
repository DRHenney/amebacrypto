#!/bin/bash
# Script para fazer deploy do hook atualizado com suporte a fees reais

set -a
source .env 2>/dev/null || {
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
}
set +a

# Detectar caminho do forge
FORGE_CMD="forge"
if ! command -v forge &> /dev/null; then
    # Tentar caminho padrão do foundry
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        FORGE_CMD="$HOME/.foundry/bin/forge"
    elif [ -f "$HOME/.foundry/versions/stable/forge" ]; then
        FORGE_CMD="$HOME/.foundry/versions/stable/forge"
    else
        echo "❌ Erro: forge não encontrado!"
        echo "Instale o Foundry: curl -L https://foundry.paradigm.xyz | bash"
        exit 1
    fi
fi

echo "🚀 Deploy do Hook Atualizado (com suporte a fees reais)"
echo "========================================================"
echo ""
echo "📍 Configuração:"
echo "  PoolManager: $POOL_MANAGER"
echo "  RPC: $SEPOLIA_RPC_URL"
echo ""

echo "════════════════════════════════════════════════"
echo "  Deploy do Hook Atualizado"
echo "════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/DeployAutoCompoundHook.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   1. Copie o Hook Address acima"
echo "   2. Atualize HOOK_ADDRESS no .env"
echo "   3. Crie uma nova pool com o novo hook"
echo "   4. Ou use a pool existente se possível"
echo ""

