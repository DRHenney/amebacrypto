#!/bin/bash
# Script para criar pool e configurar hook (após deploy)
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

if [ -z "$HOOK_ADDRESS" ]; then
    echo "❌ Erro: HOOK_ADDRESS não configurado no .env"
    echo "   Execute primeiro: bash deploy-hook-atualizado.sh"
    exit 1
fi

echo "════════════════════════════════════════════════"
echo "  PASSO 2/5: Criar Pool"
echo "════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/CreatePool.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Pool criada!"
echo ""

echo "════════════════════════════════════════════════"
echo "  PASSO 3/5: Adicionar Liquidez"
echo "════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/AddLiquidity.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Liquidez adicionada!"
echo ""

echo "════════════════════════════════════════════════"
echo "  PASSO 4/5: Configurar Hook"
echo "════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/ConfigureHook.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Hook configurado!"
echo ""

echo "════════════════════════════════════════════════"
echo "  PASSO 5/5: Verificar Estado"
echo "════════════════════════════════════════════════"
echo ""

bash verificar-estado-hook.sh

echo ""
echo "✅ Deploy completo! Agora você pode:"
echo "  1. Executar swaps: bash executar-multiplos-swaps.sh"
echo "  2. Testar compound: bash executar-compound.sh"
echo ""


