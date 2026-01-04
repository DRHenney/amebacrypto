#!/bin/bash
# Script para fazer deploy do PoolManager na Sepolia

echo "🚀 Deploy do PoolManager na Sepolia"
echo "===================================="
echo ""

# Carregar variáveis do .env
set -a
source .env 2>/dev/null || {
    echo "❌ Erro: Arquivo .env não encontrado!"
    echo "   Certifique-se de estar na raiz do projeto"
    exit 1
}
set +a

# Verificar se as variáveis estão definidas
if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "sua_chave_privada_aqui" ]; then
    echo "❌ Erro: PRIVATE_KEY não configurada no .env"
    exit 1
fi

if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo "❌ Erro: SEPOLIA_RPC_URL não configurada no .env"
    exit 1
fi

echo "✅ Configurações encontradas"
echo "   RPC: $SEPOLIA_RPC_URL"
echo ""

# Verificar saldo
echo "📊 Verificando saldo da carteira..."
ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "   Endereço: $ADDRESS"
    BALANCE=$(cast balance $ADDRESS --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "   Saldo: $(cast --to-unit $BALANCE ether) ETH"
        if [ $(cast --to-unit $BALANCE ether | cut -d. -f1) -eq 0 ]; then
            echo "   ⚠️  Saldo muito baixo! Você precisa de ETH na Sepolia"
        fi
    fi
fi

echo ""
echo "🔨 Iniciando deploy do PoolManager..."
echo ""

# Fazer deploy
forge script script/DeployPoolManagerSepolia.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deploy concluído com sucesso!"
    echo ""
    echo "📝 IMPORTANTE: Copie o endereço do PoolManager mostrado acima"
    echo "   e adicione ao arquivo .env como: POOL_MANAGER=0x..."
else
    echo ""
    echo "❌ Erro no deploy. Verifique os erros acima."
fi



