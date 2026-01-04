#!/bin/bash
# Script para encontrar o endereço do PoolManager deployado

echo "🔍 Procurando endereço do PoolManager deployado..."
echo ""

# Opção 1: Verificar arquivos de broadcast
echo "1. Verificando arquivos de broadcast..."
if [ -d "broadcast" ]; then
    echo "   Procurando em broadcast/..."
    find broadcast -name "*.json" -type f -exec grep -l "PoolManager\|DeployPoolManager" {} \; 2>/dev/null | while read file; do
        echo "   Arquivo encontrado: $file"
        # Tentar extrair endereços
        grep -o "0x[a-fA-F0-9]\{40\}" "$file" | head -1 | while read addr; do
            echo "   Endereço encontrado: $addr"
        done
    done
fi

echo ""
echo "2. Para encontrar pela carteira no Etherscan:"
echo "   a) Abra: https://sepolia.etherscan.io/"
echo "   b) Cole o endereço da sua carteira"
echo "   c) Veja as transações mais recentes"
echo "   d) A transação de 'Contract Creation' mostra o endereço do contrato"

echo ""
echo "3. Para ver o endereço que seria deployado (simulação):"
echo "   Execute: forge script script/DeployPoolManagerSepolia.s.sol --rpc-url https://rpc.sepolia.org"
echo "   (sem --broadcast)"



