#!/bin/bash
# Script para acumular fees automaticamente até atingir threshold
# Faz swaps continuamente até acumular ~0.001 WETH em fees

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

echo "🔄 Acumulando Fees Automaticamente até Threshold"
echo "=================================================="
echo ""
echo "📊 Configuração:"
echo "  Target: 0.001 WETH (~\$3)"
echo "  Swap Size: 0.001 WETH por swap"
echo "  Estimativa: ~333 swaps"
echo ""

echo "⚠️  Este processo pode demorar e consumir bastante gas!"
echo "   Você pode interromper a qualquer momento com Ctrl+C"
echo ""
read -p "Deseja continuar? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Cancelado pelo usuário"
    exit 1
fi

echo ""
echo "🚀 Iniciando acumulação de fees..."
echo ""

$FORGE_CMD script script/AccumulateFeesUntilThreshold.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvv

echo ""
echo "✅ Processo concluído!"
echo ""
echo "💡 Próximos passos:"
echo "  1. Verificar fees: bash verificar-estado-hook.sh"
echo "  2. Testar compound: bash executar-compound.sh"
echo ""


