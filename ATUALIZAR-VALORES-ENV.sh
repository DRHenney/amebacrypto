#!/bin/bash
# Script para atualizar valores no .env com os tokens disponíveis

echo "📝 Atualizando valores no .env..."
echo ""

if [ ! -f .env ]; then
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
fi

# Valores recomendados (1 USDC e 0.01 WETH)
USDC_AMOUNT=1000000  # 1 USDC (6 decimais)
WETH_AMOUNT=10000000000000000  # 0.01 WETH (18 decimais)
SWAP_AMOUNT=100000  # 0.1 USDC para swaps

echo "Atualizando valores para:"
echo "  USDC: $USDC_AMOUNT (1 USDC)"
echo "  WETH: $WETH_AMOUNT (0.01 WETH)"
echo ""

# Atualizar ou adicionar LIQUIDITY_TOKEN0_AMOUNT
if grep -q "^LIQUIDITY_TOKEN0_AMOUNT=" .env; then
    sed -i "s/^LIQUIDITY_TOKEN0_AMOUNT=.*/LIQUIDITY_TOKEN0_AMOUNT=$USDC_AMOUNT/" .env
    echo "✅ Atualizado LIQUIDITY_TOKEN0_AMOUNT"
else
    echo "LIQUIDITY_TOKEN0_AMOUNT=$USDC_AMOUNT" >> .env
    echo "✅ Adicionado LIQUIDITY_TOKEN0_AMOUNT"
fi

# Atualizar ou adicionar LIQUIDITY_TOKEN1_AMOUNT
if grep -q "^LIQUIDITY_TOKEN1_AMOUNT=" .env; then
    sed -i "s/^LIQUIDITY_TOKEN1_AMOUNT=.*/LIQUIDITY_TOKEN1_AMOUNT=$WETH_AMOUNT/" .env
    echo "✅ Atualizado LIQUIDITY_TOKEN1_AMOUNT"
else
    echo "LIQUIDITY_TOKEN1_AMOUNT=$WETH_AMOUNT" >> .env
    echo "✅ Adicionado LIQUIDITY_TOKEN1_AMOUNT"
fi

# Atualizar ou adicionar SWAP_AMOUNT
if grep -q "^SWAP_AMOUNT=" .env; then
    sed -i "s/^SWAP_AMOUNT=.*/SWAP_AMOUNT=$SWAP_AMOUNT/" .env
    echo "✅ Atualizado SWAP_AMOUNT"
else
    echo "SWAP_AMOUNT=$SWAP_AMOUNT" >> .env
    echo "✅ Adicionado SWAP_AMOUNT"
fi

echo ""
echo "✅ Valores atualizados com sucesso!"
echo ""
echo "Valores finais:"
grep "LIQUIDITY_TOKEN\|SWAP_AMOUNT" .env


