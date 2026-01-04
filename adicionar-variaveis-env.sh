#!/bin/bash
# Script para adicionar as variáveis necessárias ao .env

echo "📝 Adicionando variáveis ao .env..."
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    echo "❌ Erro: Arquivo .env não encontrado!"
    echo "   Execute primeiro: bash setup-sepolia.sh"
    exit 1
fi

# Verificar se as variáveis já existem
if grep -q "LIQUIDITY_TOKEN0_AMOUNT" .env; then
    echo "⚠️  Variáveis já existem no .env"
    echo "   Pulando adição..."
    exit 0
fi

# Adicionar as variáveis ao final do .env
cat >> .env << 'EOF'

# ============================================
# LIQUIDEZ E SWAPS
# ============================================
# Valores para adicionar liquidez (em smallest units)
# Ajuste conforme seus tokens disponíveis
LIQUIDITY_TOKEN0_AMOUNT=1000000  # 1 USDC (6 decimais) - ajuste conforme conseguir mais
LIQUIDITY_TOKEN1_AMOUNT=10000000000000000  # 0.01 WETH (18 decimais) - ajuste conforme necessário

# Valor para testar swaps
SWAP_AMOUNT=10000000  # 10 USDC (6 decimais) ou ajuste conforme necessário
EOF

echo "✅ Variáveis adicionadas ao .env com sucesso!"
echo ""
echo "Valores adicionados:"
echo "  - LIQUIDITY_TOKEN0_AMOUNT=100000000 (100 USDC)"
echo "  - LIQUIDITY_TOKEN1_AMOUNT=100000000000000000 (0.1 WETH)"
echo "  - SWAP_AMOUNT=10000000 (10 USDC)"
echo ""
echo "Você pode ajustar esses valores no .env se necessário."
