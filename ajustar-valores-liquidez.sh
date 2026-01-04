#!/bin/bash
# Script para ajustar valores de liquidez no .env

echo "📝 Ajustando valores de liquidez no .env..."
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
fi

echo "Valores atuais:"
grep "LIQUIDITY_TOKEN" .env || echo "Variáveis não encontradas"
echo ""

read -p "Deseja ajustar os valores? (s/n): " resposta

if [ "$resposta" != "s" ]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "⚠️  IMPORTANTE:"
echo "   - USDC tem 6 decimais (100 USDC = 100000000)"
echo "   - WETH tem 18 decimais (0.1 WETH = 100000000000000000)"
echo ""

read -p "Quantos USDC você quer adicionar? (ex: 10 para 10 USDC): " usdc_amount
read -p "Quantos WETH você quer adicionar? (ex: 0.01 para 0.01 WETH): " weth_amount

# Calcular valores em smallest units
usdc_smallest=$(echo "$usdc_amount * 1000000" | bc)
weth_smallest=$(echo "$weth_amount * 1000000000000000000" | bc)

# Converter para inteiro (remover decimais)
usdc_int=$(echo "$usdc_smallest" | cut -d. -f1)
weth_int=$(echo "$weth_smallest" | cut -d. -f1)

echo ""
echo "Valores calculados:"
echo "  Token0 (USDC): $usdc_int (equivale a $usdc_amount USDC)"
echo "  Token1 (WETH): $weth_int (equivale a $weth_amount WETH)"
echo ""

read -p "Confirmar e atualizar .env? (s/n): " confirmar

if [ "$confirmar" != "s" ]; then
    echo "Cancelado."
    exit 0
fi

# Atualizar .env
if grep -q "LIQUIDITY_TOKEN0_AMOUNT" .env; then
    sed -i "s/^LIQUIDITY_TOKEN0_AMOUNT=.*/LIQUIDITY_TOKEN0_AMOUNT=$usdc_int/" .env
else
    echo "LIQUIDITY_TOKEN0_AMOUNT=$usdc_int" >> .env
fi

if grep -q "LIQUIDITY_TOKEN1_AMOUNT" .env; then
    sed -i "s/^LIQUIDITY_TOKEN1_AMOUNT=.*/LIQUIDITY_TOKEN1_AMOUNT=$weth_int/" .env
else
    echo "LIQUIDITY_TOKEN1_AMOUNT=$weth_int" >> .env
fi

echo ""
echo "✅ Valores atualizados no .env!"
echo ""
echo "Novos valores:"
grep "LIQUIDITY_TOKEN" .env


