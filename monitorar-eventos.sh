#!/bin/bash
# Script para monitorar eventos do hook na Sepolia

echo "📡 Monitorando Eventos do Hook na Sepolia..."
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
if [ -z "$HOOK_ADDRESS" ]; then
    echo "❌ Erro: HOOK_ADDRESS não configurada"
    exit 1
fi

HOOK=$HOOK_ADDRESS

echo "📍 Hook Address: $HOOK"
echo ""

# Verificar se cast está disponível
if ! command -v cast &> /dev/null; then
    echo "❌ Erro: cast não encontrado. Instale foundry primeiro."
    exit 1
fi

# Definir o bloco inicial (últimas 10000 blocks ou desde um bloco específico)
# Se não especificado, usa os últimos 10000 blocks
FROM_BLOCK=${FROM_BLOCK:-"latest"}
if [ "$FROM_BLOCK" != "latest" ] && [ -z "$FROM_BLOCK" ]; then
    LATEST_BLOCK=$(cast block-number --rpc-url $SEPOLIA_RPC_URL)
    FROM_BLOCK=$((LATEST_BLOCK - 10000))
fi

echo "🔍 Buscando eventos a partir do bloco: $FROM_BLOCK"
echo ""

# Eventos para monitorar
echo "=== Event: FeesCompounded ==="
cast logs \
    --address $HOOK \
    --event "FeesCompounded(bytes32 indexed poolId, uint256 amount0, uint256 amount1)" \
    --from-block $FROM_BLOCK \
    --rpc-url $SEPOLIA_RPC_URL 2>/dev/null | head -50

echo ""
echo "=== Event: PoolConfigUpdated ==="
cast logs \
    --address $HOOK \
    --event "PoolConfigUpdated(bytes32 indexed poolId, bool enabled)" \
    --from-block $FROM_BLOCK \
    --rpc-url $SEPOLIA_RPC_URL 2>/dev/null | head -50

echo ""
echo "=== Event: TokenPricesUpdated ==="
cast logs \
    --address $HOOK \
    --event "TokenPricesUpdated(bytes32 indexed poolId, uint256 price0USD, uint256 price1USD)" \
    --from-block $FROM_BLOCK \
    --rpc-url $SEPOLIA_RPC_URL 2>/dev/null | head -50

echo ""
echo "=== Event: PoolTickRangeUpdated ==="
cast logs \
    --address $HOOK \
    --event "PoolTickRangeUpdated(bytes32 indexed poolId, int24 tickLower, int24 tickUpper)" \
    --from-block $FROM_BLOCK \
    --rpc-url $SEPOLIA_RPC_URL 2>/dev/null | head -50

echo ""
echo "=== Event: OwnerUpdated ==="
cast logs \
    --address $HOOK \
    --event "OwnerUpdated(address indexed oldOwner, address indexed newOwner)" \
    --from-block $FROM_BLOCK \
    --rpc-url $SEPOLIA_RPC_URL 2>/dev/null | head -50

echo ""
echo "✅ Monitoramento concluído!"
echo ""
echo "💡 Dica: Para monitorar eventos em tempo real, use:"
echo "   watch -n 10 ./monitorar-eventos.sh"

