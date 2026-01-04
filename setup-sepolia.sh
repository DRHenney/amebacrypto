#!/bin/bash
# Script de Setup para Sepolia - AutoCompoundHook

echo "🚀 Setup Sepolia - AutoCompoundHook"
echo "===================================="
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    echo "📝 Criando arquivo .env..."
    cat > .env << 'EOF'
# ============================================
# CARTEIRA E REDE
# ============================================
# Chave privada da carteira (SEM 0x no início)
# IMPORTANTE: Substitua pela sua chave privada
PRIVATE_KEY=SUA_CHAVE_PRIVADA_AQUI

# RPC URL da Sepolia
# Opção 1: RPC público (pode ser lento)
SEPOLIA_RPC_URL=https://rpc.sepolia.org

# Opção 2: Alchemy (recomendado - crie conta grátis em alchemy.com)
# SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/SEU_API_KEY

# Opção 3: Infura (recomendado - crie conta grátis em infura.io)
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/SEU_API_KEY

# ============================================
# UNISWAP V4
# ============================================
# Endereço do PoolManager (será preenchido após deploy do PoolManager)
POOL_MANAGER=

# ============================================
# HOOK (será preenchido após deploy)
# ============================================
HOOK_ADDRESS=

# ============================================
# POOL CONFIGURATION
# ============================================
# Endereços dos tokens na Sepolia
TOKEN0_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238  # USDC Sepolia
TOKEN1_ADDRESS=0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14  # WETH Sepolia

# Preços dos tokens em USD (formato: price * 1e18)
# USDC = $1 -> 1000000000000000000 (1e18)
# ETH = $3000 -> 3000000000000000000000 (3000e18)
TOKEN0_PRICE_USD=1000000000000000000
TOKEN1_PRICE_USD=3000000000000000000000

# Tick range para adicionar liquidez no compound
TICK_LOWER=-887272
TICK_UPPER=887272

# ============================================
# ETHERSCAN (opcional - para verificação)
# ============================================
ETHERSCAN_API_KEY=
EOF
    echo "✅ Arquivo .env criado!"
    echo ""
    echo "⚠️  IMPORTANTE: Edite o arquivo .env e adicione sua chave privada!"
    echo "   Abra o arquivo .env e substitua 'SUA_CHAVE_PRIVADA_AQUI' pela sua chave privada"
    echo ""
else
    echo "✅ Arquivo .env já existe!"
    echo ""
fi

echo "📚 Próximos passos:"
echo ""
echo "1. Edite o arquivo .env e adicione sua chave privada"
echo "2. Obtenha Sepolia ETH: https://sepoliafaucet.com/"
echo "3. Execute: forge script script/testing/00_DeployV4.s.sol --rpc-url \$SEPOLIA_RPC_URL --broadcast -vvvv"
echo "4. Após deploy do PoolManager, atualize POOL_MANAGER no .env"
echo "5. Execute o deploy do hook"
echo ""
echo "📖 Leia SEPOLIA-SETUP.md para mais detalhes!"



