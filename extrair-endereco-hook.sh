#!/bin/bash
# Script para extrair o endereço do hook do output do deploy

echo "🔍 Procurando endereço do Hook..."
echo ""

# Procurar no arquivo de broadcast mais recente
LATEST_FILE=$(find broadcast/DeployAutoCompoundHook.s.sol/11155111 -name "run-*.json" -type f | sort -r | head -1)

if [ -n "$LATEST_FILE" ]; then
    echo "Arquivo encontrado: $LATEST_FILE"
    echo ""
    
    # Extrair endereço do contrato
    HOOK_ADDRESS=$(jq -r '.transactions[0].contractAddress // empty' "$LATEST_FILE" 2>/dev/null)
    
    if [ -n "$HOOK_ADDRESS" ] && [ "$HOOK_ADDRESS" != "null" ]; then
        echo "✅ Endereço do Hook encontrado:"
        echo "   $HOOK_ADDRESS"
        echo ""
        echo "Para atualizar o .env, execute:"
        echo "   sed -i 's/^HOOK_ADDRESS=.*/HOOK_ADDRESS=$HOOK_ADDRESS/' .env"
    else
        echo "⚠️  Não foi possível extrair o endereço do arquivo JSON"
        echo ""
        echo "Procure no output do comando forge script por:"
        echo "  - 'Hook Address:' ou"
        echo "  - 'AutoCompoundHook deployed at:' ou"
        echo "  - 'Contract Address:'"
    fi
else
    echo "⚠️  Arquivo de broadcast não encontrado"
    echo ""
    echo "Procure no output do terminal por uma destas linhas:"
    echo ""
    echo "=== Deploy Summary ==="
    echo "Hook Address: 0x..."
    echo ""
    echo "OU"
    echo ""
    echo "Contract Address: 0x..."
    echo ""
    echo "OU"
    echo ""
    echo "AutoCompoundHook deployed at: 0x..."
fi



