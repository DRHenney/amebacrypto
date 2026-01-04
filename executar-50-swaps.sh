#!/bin/bash
# Script para executar 50 swaps para gerar fees
# Usa um tamanho pequeno de swap para funcionar com saldo limitado

cd "$(dirname "$0")"
source .env

FORGE_CMD="forge"
if ! command -v forge &> /dev/null; then
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        FORGE_CMD="$HOME/.foundry/bin/forge"
    elif [ -f "$HOME/.foundry/versions/stable/forge" ]; then
        FORGE_CMD="$HOME/.foundry/versions/stable/forge"
    fi
fi

echo "🔄 Executando 50 swaps para gerar fees..."
echo ""

# Usar um tamanho muito pequeno de swap (0.00001 WETH = 10000000000000 wei)
# Com isso, podemos fazer muitos swaps mesmo com saldo limitado
SWAP_SIZE=10000000000000  # 0.00001 WETH

# Calcular quantos swaps podemos fazer com o saldo atual
# Vamos fazer loops menores para evitar problemas
BATCH_SIZE=10  # Fazer 10 swaps por vez

echo "Tamanho por swap: $SWAP_SIZE wei (0.00001 WETH)"
echo "Fazendo em batches de $BATCH_SIZE swaps"
echo ""

for BATCH in {1..5}; do
    echo "=== Batch $BATCH de 5 (10 swaps cada) ==="
    
    export NUM_SWAPS=10
    export SWAP_WETH_AMOUNT=$SWAP_SIZE
    export ALTERNATE_DIRECTIONS=false  # Apenas WETH -> USDC
    
    $FORGE_CMD script script/MultipleSwaps.s.sol:MultipleSwaps \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --broadcast \
        --private-key "$PRIVATE_KEY" \
        -vvv 2>&1 | grep -E "(Swap number|Success|Fees accumulated|Error|failed)" | tail -20
    
    echo ""
    sleep 2  # Pequena pausa entre batches
done

echo ""
echo "✅ Todos os swaps executados!"
echo "💡 Execute './verificar-estado-hook.sh' para ver as fees acumuladas"

