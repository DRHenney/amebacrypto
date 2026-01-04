#!/bin/bash
# Script para verificar saldos de tokens na Sepolia

echo "🔍 Verificando saldos de tokens..."
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
if [ -z "$TOKEN0_ADDRESS" ] || [ -z "$TOKEN1_ADDRESS" ]; then
    echo "❌ Erro: TOKEN0_ADDRESS ou TOKEN1_ADDRESS não configuradas"
    exit 1
fi

# Obter endereço da carteira
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Erro: PRIVATE_KEY não configurada"
    exit 1
fi

WALLET_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null)

if [ -z "$WALLET_ADDRESS" ]; then
    echo "❌ Erro ao obter endereço da carteira"
    exit 1
fi

echo "Carteira: $WALLET_ADDRESS"
echo ""

# Verificar saldo de ETH
ETH_BALANCE=$(cast balance $WALLET_ADDRESS --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
if [ $? -eq 0 ]; then
    ETH_BALANCE_ETH=$(cast --to-unit $ETH_BALANCE ether)
    echo "ETH: $ETH_BALANCE_ETH ETH"
else
    echo "⚠️  Erro ao verificar saldo de ETH"
fi

# Verificar saldo de USDC (Token0)
echo ""
echo "Verificando saldo de USDC..."
USDC_BALANCE=$(cast call $TOKEN0_ADDRESS "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$USDC_BALANCE" ]; then
    # USDC tem 6 decimais
    USDC_BALANCE_DECIMAL=$(echo "scale=6; $USDC_BALANCE / 1000000" | bc)
    echo "USDC: $USDC_BALANCE_DECIMAL USDC ($USDC_BALANCE)"
else
    echo "⚠️  Erro ao verificar saldo de USDC"
fi

# Verificar saldo de WETH (Token1)
echo ""
echo "Verificando saldo de WETH..."
WETH_BALANCE=$(cast call $TOKEN1_ADDRESS "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$WETH_BALANCE" ]; then
    # WETH tem 18 decimais
    WETH_BALANCE_DECIMAL=$(echo "scale=18; $WETH_BALANCE / 1000000000000000000" | bc)
    echo "WETH: $WETH_BALANCE_DECIMAL WETH ($WETH_BALANCE)"
else
    echo "⚠️  Erro ao verificar saldo de WETH"
fi

echo ""
echo "✅ Verificação concluída!"
echo ""
echo "Valores configurados no .env:"
echo "  LIQUIDITY_TOKEN0_AMOUNT: $(grep '^LIQUIDITY_TOKEN0_AMOUNT=' .env | cut -d'=' -f2)"
echo "  LIQUIDITY_TOKEN1_AMOUNT: $(grep '^LIQUIDITY_TOKEN1_AMOUNT=' .env | cut -d'=' -f2)"


