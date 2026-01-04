#!/bin/bash

# Script para transferir ETH de um endereço para outro
# Configurações necessárias no .env:
# - SENDER_PRIVATE_KEY: chave privada do endereço que vai enviar ETH
# - RECIPIENT_ADDRESS: endereço que vai receber (opcional, usa PRIVATE_KEY se não especificado)
# - TRANSFER_AMOUNT: quantidade em wei (opcional, default: 0.1 ETH)

cd "$(dirname "$0")"
source .env

echo "🔄 Transferindo ETH entre endereços..."

# Verificar se SENDER_PRIVATE_KEY está configurado
if [ -z "$SENDER_PRIVATE_KEY" ]; then
    echo "❌ Erro: SENDER_PRIVATE_KEY não configurado no .env"
    echo ""
    echo "Adicione ao .env:"
    echo "SENDER_PRIVATE_KEY=sua_chave_privada_do_endereco_que_tem_ETH"
    echo ""
    echo "Opção: RECIPIENT_ADDRESS=0x63f976191f9Dd75bd5b0fD81320D37FBC0d74080 (opcional)"
    echo "Opção: TRANSFER_AMOUNT=100000000000000000 (0.1 ETH em wei, opcional)"
    exit 1
fi

/home/derek/.foundry/versions/stable/forge script script/TransferETH.s.sol:TransferETH \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --private-key "$SENDER_PRIVATE_KEY" \
    -vvv

echo ""
echo "✅ Transferência concluída!"

