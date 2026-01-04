#!/bin/bash
# Script para verificar o estado completo do hook na Sepolia

echo "🔍 Verificando Estado do Hook na Sepolia..."
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

echo "📍 Endereços:"
echo "  Hook: $HOOK_ADDRESS"
echo "  PoolManager: $POOL_MANAGER"
echo ""

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

# Executar script de verificação
$FORGE_CMD script script/VerifyHookState.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  -vvv

echo ""
echo "✅ Verificação concluída!"

