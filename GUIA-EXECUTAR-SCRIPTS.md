# Guia para Executar os Scripts

Este guia explica como usar os scripts para criar pool, adicionar liquidez e testar swaps.

## Pré-requisitos

1. ✅ PoolManager deployado
2. ✅ Hook deployado e configurado
3. ✅ Tokens disponíveis (USDC e WETH na Sepolia)
4. ✅ `.env` configurado

## Variáveis de Ambiente Necessárias

Adicione estas variáveis ao seu `.env`:

```bash
# Variáveis já existentes (manter)
PRIVATE_KEY=0x...
POOL_MANAGER=0x...
HOOK_ADDRESS=0x...
TOKEN0_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238  # USDC Sepolia
TOKEN1_ADDRESS=0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14  # WETH Sepolia
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com

# Variáveis para AddLiquidity
LIQUIDITY_TOKEN0_AMOUNT=100000000  # 100 USDC (6 decimals)
LIQUIDITY_TOKEN1_AMOUNT=100000000000000000  # 0.1 WETH (18 decimals)

# Variáveis para TestSwaps
SWAP_AMOUNT=10000000  # 10 USDC (6 decimals) ou 0.01 WETH (18 decimals)
```

**⚠️ IMPORTANTE:** 
- USDC na Sepolia tem **6 decimais**
- WETH tem **18 decimais**
- Ajuste os valores conforme necessário

---

## Executar os Scripts

### Opção 1: Usar o Script Automático (Recomendado)

```bash
chmod +x executar-scripts-pool.sh
./executar-scripts-pool.sh
```

O script irá:
1. Carregar variáveis do `.env`
2. Perguntar qual ação executar (criar pool, adicionar liquidez, testar swaps, ou todos)
3. Executar com as configurações corretas

---

### Opção 2: Executar Manualmente

Primeiro, carregue as variáveis do `.env`:
```bash
source .env
# ou
set -a && source .env && set +a
```

## Passo 1: Criar a Pool

Cria/Inicializa a pool no Uniswap v4.

```bash
forge script script/CreatePool.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

**OU usando a URL direta:**
```bash
forge script script/CreatePool.s.sol \
  --rpc-url https://ethereum-sepolia-rpc.publicnode.com \
  --broadcast \
  -vvvv
```

**O que faz:**
- Inicializa a pool com preço 1:1
- Configura fee de 0.3%
- Tick spacing de 60
- Usa o hook deployado

**Resultado esperado:**
```
Pool initialized successfully!
Initial Tick: 0
```

---

## Passo 2: Adicionar Liquidez

Adiciona liquidez inicial à pool.

**⚠️ ANTES:** Certifique-se de ter:
- Tokens aprovados para o PoolManager
- Saldo suficiente dos tokens

```bash
forge script script/AddLiquidity.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

**O que faz:**
- Adiciona liquidez em full range (-887272 a 887272)
- Usa os valores de `LIQUIDITY_TOKEN0_AMOUNT` e `LIQUIDITY_TOKEN1_AMOUNT` do `.env`

**Resultado esperado:**
```
Liquidity added successfully!
Delta Amount0: -100000000  (negativo = você depositou)
Delta Amount1: -100000000000000000  (negativo = você depositou)
```

---

## Passo 3: Testar Swaps e Verificar Fees

Executa swaps e verifica se as fees estão sendo acumuladas.

```bash
forge script script/TestSwaps.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

**O que faz:**
- Executa 2 swaps (Token0 -> Token1 e Token1 -> Token0)
- Mostra fees acumuladas após cada swap
- Verifica status do compound

**Resultado esperado:**
```
=== Initial State ===
Fees0 Before: 0
Fees1 Before: 0

=== Swap 1: Token0 -> Token1 ===
Swap 1 Result:
Delta Amount0: -10000000
Delta Amount1: 9970000...
Accumulated Fee0: 30000  (0.3% de 10 USDC)

=== Swap 2: Token1 -> Token0 ===
...

=== Final State ===
Fees0 Final: 30000
Fees1 Final: 15000...
Total Accumulated Fee0: 30000
Total Accumulated Fee1: 15000...

=== Compound Status ===
Can Execute: false
Reason: No accumulated fees (pode mostrar outras razões)
```

---

## Troubleshooting

### Erro: "Pool not initialized"
- Execute primeiro o script `CreatePool.s.sol`

### Erro: "Insufficient balance"
- Verifique se você tem tokens suficientes
- Verifique os decimais (USDC = 6, WETH = 18)

### Erro: "ManagerLocked"
- Isso é normal, o script usa `unlock()` automaticamente

### Fees não estão acumulando
- Verifique se o hook está habilitado (`setPoolConfig` foi chamado)
- Verifique se o hook está corretamente configurado

### Aprovação de tokens
- Os scripts aprovam automaticamente, mas você pode precisar fazer manualmente:
  ```solidity
  IERC20(token0).approve(poolManager, type(uint256).max);
  IERC20(token1).approve(poolManager, type(uint256).max);
  ```

---

## Próximos Passos

Após executar os swaps e verificar que as fees estão acumulando:

1. **Aguardar 4 horas** para o cooldown do compound
2. **Acumular fees suficientes** (> 20x o custo de gas)
3. **Executar compound manualmente** chamando `checkAndCompound()` no hook

---

## Verificar Fees Manualmente

Você pode verificar as fees acumuladas usando o hook:

```solidity
AutoCompoundHook hook = AutoCompoundHook(hookAddress);
PoolKey memory key = ...; // mesmo PoolKey usado nos scripts
(,, uint256 fees0, uint256 fees1,,) = hook.getPoolInfo(key);
```

Ou via Etherscan, chamando a função `getPoolInfo` do hook.

---

## Scripts Criados

✅ `script/CreatePool.s.sol` - Inicializa a pool  
✅ `script/AddLiquidity.s.sol` - Adiciona liquidez  
✅ `script/TestSwaps.s.sol` - Testa swaps e verifica fees  

Todos os scripts estão prontos para uso! 🚀
