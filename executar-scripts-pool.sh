#!/bin/bash
# Script para executar os scripts de pool, liquidez e swaps

echo "🚀 Executando Scripts de Pool"
echo "=============================="
echo ""

# Carregar variáveis do .env
set -a
source .env 2>/dev/null || {
    echo "❌ Erro: Arquivo .env não encontrado!"
    exit 1
}
set +a

# Verificar se SEPOLIA_RPC_URL está definida
if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo "❌ Erro: SEPOLIA_RPC_URL não configurada no .env"
    exit 1
fi

echo "✅ RPC URL: $SEPOLIA_RPC_URL"
echo ""

# Perguntar qual script executar
echo "Qual script deseja executar?"
echo "1) Criar Pool"
echo "2) Adicionar Liquidez"
echo "3) Testar Swaps"
echo "4) Executar todos (1 -> 2 -> 3)"
echo "5) Wrap ETH para WETH"
echo "6) Swap WETH -> USDC (obter mais USDC)"
echo "7) Testar Auto-Compound"
echo ""
read -p "Escolha (1-7): " escolha

case $escolha in
    1)
        echo ""
        echo "🔨 Criando Pool..."
        forge script script/CreatePool.s.sol \
          --rpc-url $SEPOLIA_RPC_URL \
          --broadcast \
          -vvvv
        ;;
    2)
        echo ""
        echo "💧 Adicionando Liquidez..."
        forge script script/AddLiquidity.s.sol \
          --rpc-url $SEPOLIA_RPC_URL \
          --broadcast \
          -vvvv
        ;;
    3)
        echo ""
        echo "🔄 Testando Swaps..."
        forge script script/TestSwaps.s.sol \
          --rpc-url $SEPOLIA_RPC_URL \
          --broadcast \
          -vvvv
        ;;
    5)
        echo ""
        echo "🔄 Fazendo Wrap de ETH para WETH..."
        forge script script/WrapETH.s.sol \
          --rpc-url $SEPOLIA_RPC_URL \
          --broadcast \
          -vvvv
        ;;
    6)
        echo ""
        echo "💱 Fazendo Swap de WETH para USDC..."
        forge script script/SwapWETHForUSDC.s.sol \
          --rpc-url $SEPOLIA_RPC_URL \
          --broadcast \
          -vvvv
        ;;
    7)
        echo ""
        echo "🔄 Testando Auto-Compound..."
        forge script script/TestCompound.s.sol \
          --rpc-url $SEPOLIA_RPC_URL \
          --broadcast \
          -vvvv
        ;;
    4)
        echo ""
        echo "🔨 Passo 1: Criando Pool..."
        forge script script/CreatePool.s.sol \
          --rpc-url $SEPOLIA_RPC_URL \
          --broadcast \
          -vvvv
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "✅ Pool criada! Aguardando 5 segundos antes do próximo passo..."
            sleep 5
            
            echo ""
            echo "💧 Passo 2: Adicionando Liquidez..."
            forge script script/AddLiquidity.s.sol \
              --rpc-url $SEPOLIA_RPC_URL \
              --broadcast \
              -vvvv
            
            if [ $? -eq 0 ]; then
                echo ""
                echo "✅ Liquidez adicionada! Aguardando 5 segundos antes do próximo passo..."
                sleep 5
                
                echo ""
                echo "🔄 Passo 3: Testando Swaps..."
                forge script script/TestSwaps.s.sol \
                  --rpc-url $SEPOLIA_RPC_URL \
                  --broadcast \
                  -vvvv
            fi
        fi
        ;;
    *)
        echo "❌ Opção inválida!"
        exit 1
        ;;
esac

echo ""
echo "✅ Concluído!"
