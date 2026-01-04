#!/bin/bash
# Script para testar conexão com RPC e fazer deploy

echo "🔍 Testando conexão com RPC..."
echo ""

source .env 2>/dev/null || {
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
}

echo "RPC: $SEPOLIA_RPC_URL"
echo ""

# Testar conexão
echo "📡 Testando RPC..."
BLOCK=$(cast block-number --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ RPC funcionando! Block atual: $BLOCK"
    echo ""
    echo "🚀 Iniciando deploy do PoolManager..."
    echo ""
    forge script script/DeployPoolManagerSepolia.s.sol \
      --rpc-url $SEPOLIA_RPC_URL \
      --broadcast \
      -vvvv
else
    echo "❌ Erro ao conectar com RPC"
    echo ""
    echo "Tente uma destas opções:"
    echo "1. Aguarde alguns minutos e tente novamente"
    echo "2. Use um RPC com API key (Alchemy ou Infura)"
    echo "3. Tente outro RPC público:"
    echo "   - https://sepolia.gateway.tenderly.co"
    echo "   - https://rpc2.sepolia.org"
fi



