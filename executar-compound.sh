#!/bin/bash
# Script para executar compound no hook

echo "🔄 Executando Compound..."
echo ""

# Carregar variáveis do .env
set -a
source .env 2>/dev/null || {
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
}
set +a

# Verificar se RPC está configurado
if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo "❌ Erro: SEPOLIA_RPC_URL não configurada no .env"
    exit 1
fi

# Verificar se addresses estão configuradas
if [ -z "$HOOK_ADDRESS" ] || [ -z "$POOL_MANAGER" ]; then
    echo "❌ Erro: HOOK_ADDRESS ou POOL_MANAGER não configuradas"
    exit 1
fi

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

echo "📍 Endereços:"
echo "  Hook: $HOOK_ADDRESS"
echo "  PoolManager: $POOL_MANAGER"
echo ""

# Executar script de compound
$FORGE_CMD script script/TestCompound.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv

echo ""
echo "✅ Compound executado!"

