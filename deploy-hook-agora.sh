#!/bin/bash
# Script simplificado para deploy do hook

cd /mnt/c/Users/derek/amebacrypto || exit 1

# Carregar .env
set -a
source .env 2>/dev/null || {
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
}
set +a

# Detectar forge
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

echo "🚀 Deploy do Hook Atualizado"
echo "Hook Atual: $HOOK_ADDRESS"
echo ""

# Deploy do hook
echo "📦 Deployando hook..."
$FORGE_CMD script script/DeployAutoCompoundHook.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Deploy concluído!"
echo "⚠️  IMPORTANTE: Copie o endereço do hook acima e atualize HOOK_ADDRESS no .env"

