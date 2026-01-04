#!/bin/bash
# Script para fazer novo deploy completo do hook na Sepolia
# Inclui: deploy do hook, criar pool, adicionar liquidez, configurar e testar

set -e  # Parar em caso de erro

echo "🚀 Deploy Completo do Hook Atualizado na Sepolia"
echo "=================================================="
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

# Verificar se PRIVATE_KEY está configurada
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Erro: PRIVATE_KEY não configurada"
    exit 1
fi

# Detectar caminho do forge
FORGE_CMD="forge"
if ! command -v forge &> /dev/null; then
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        FORGE_CMD="$HOME/.foundry/bin/forge"
    elif [ -f "$HOME/.foundry/versions/stable/forge" ]; then
        FORGE_CMD="$HOME/.foundry/versions/stable/forge"
    else
        echo "❌ Erro: forge não encontrado!"
        exit 1
    fi
fi

echo "📍 Configuração Atual:"
echo "  PoolManager: $POOL_MANAGER"
if [ -n "$HOOK_ADDRESS" ]; then
    echo "  Hook Atual: $HOOK_ADDRESS (será substituído)"
fi
echo "  Token0: $TOKEN0_ADDRESS"
echo "  Token1: $TOKEN1_ADDRESS"
echo ""
read -p "Deseja continuar com o deploy? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Deploy cancelado pelo usuário"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PASSO 1/6: Deploy do Hook"
echo "═══════════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/DeployAutoCompoundHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvv

echo ""
echo "✅ Hook deployado!"
echo ""
echo "⚠️  IMPORTANTE: Copie o endereço do hook acima e atualize HOOK_ADDRESS no .env"
echo "   Depois pressione Enter para continuar..."
read

# Recarregar .env para pegar novo HOOK_ADDRESS
set -a
source .env 2>/dev/null
set +a

if [ -z "$HOOK_ADDRESS" ]; then
    echo "❌ Erro: HOOK_ADDRESS não configurado no .env"
    echo "   Por favor, adicione HOOK_ADDRESS=0x... no .env e execute novamente"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PASSO 2/6: Criar Pool"
echo "═══════════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/CreatePool.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvv

echo ""
echo "✅ Pool criada!"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PASSO 3/6: Adicionar Liquidez"
echo "═══════════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/AddLiquidity.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvv

echo ""
echo "✅ Liquidez adicionada!"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PASSO 4/6: Configurar Hook"
echo "═══════════════════════════════════════════════════════"
echo ""

$FORGE_CMD script script/ConfigureHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvv

echo ""
echo "✅ Hook configurado!"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PASSO 5/6: Verificar Estado"
echo "═══════════════════════════════════════════════════════"
echo ""

bash verificar-estado-hook.sh

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PASSO 6/6: Próximos Passos"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "✅ Deploy completo realizado com sucesso!"
echo ""
echo "📋 Próximos passos recomendados:"
echo "  1. Executar swaps para acumular fees:"
echo "     forge script script/SwapWETHForUSDC.s.sol --rpc-url \$SEPOLIA_RPC_URL --broadcast"
echo ""
echo "  2. Aguardar 4 horas OU executar mais swaps"
echo ""
echo "  3. Executar compound:"
echo "     ./executar-compound.sh"
echo ""
echo "  4. Monitorar eventos:"
echo "     ./monitorar-eventos.sh"
echo ""
echo "═══════════════════════════════════════════════════════"
echo ""

