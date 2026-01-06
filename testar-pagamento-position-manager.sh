#!/bin/bash

# Script para testar pagamento de 10% das fees usando PositionManager

cd "$(dirname "$0")" || exit 1
source .env 2>/dev/null || {
    echo "Erro: Arquivo .env nao encontrado!"
    exit 1
}

echo "=== Testando Pagamento de 10% das Fees (PositionManager) ==="
echo "Timestamp: $(date)"
echo ""

/home/derek/.foundry/versions/stable/forge script script/TestRemoveLiquidityPaymentPositionManager.s.sol:TestRemoveLiquidityPaymentPositionManager \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv 2>&1 | tee /tmp/test-pagamento-position-manager.log

echo ""
echo "=== Teste concluido ==="
echo "Timestamp: $(date)"
echo ""
echo "Log completo salvo em: /tmp/test-pagamento-position-manager.log"

