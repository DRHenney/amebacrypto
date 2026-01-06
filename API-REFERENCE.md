# 📘 API Reference - AutoCompoundHook

**Versão**: 1.0  
**Última atualização**: 2025-01-05

---

## 📋 **Índice**

- [AutoCompoundHook](#autocompoundhook)
  - [Funções de Configuração](#funções-de-configuração)
  - [Funções de Compound](#funções-de-compound)
  - [Funções de Consulta](#funções-de-consulta)
  - [Funções de Emergência](#funções-de-emergência)
- [CompoundHelper](#compoundhelper)
  - [Funções Principais](#funções-principais)

---

## AutoCompoundHook

### **Funções de Configuração**

#### `setPoolConfig`

```solidity
function setPoolConfig(
    PoolKey calldata key,
    bool enabled
) external onlyOwner
```

**Descrição**: Habilita ou desabilita auto-compound para uma pool específica.

**Parâmetros:**
- `key`: PoolKey da pool a ser configurada
- `enabled`: `true` para habilitar, `false` para desabilitar

**Permissões**: Apenas `owner`

**Eventos**: `PoolConfigUpdated(PoolId indexed poolId, bool enabled)`

**Exemplo:**
```solidity
hook.setPoolConfig(poolKey, true);
```

---

#### `setTokenPricesUSD`

```solidity
function setTokenPricesUSD(
    PoolKey calldata key,
    uint256 price0USD,
    uint256 price1USD
) external onlyOwner
```

**Descrição**: Configura os preços dos tokens em USD. Necessário para calcular o valor das fees e verificar o threshold de 20x gas cost.

**Parâmetros:**
- `key`: PoolKey da pool
- `price0USD`: Preço do token0 em USD (ex: `3000e18` para ETH = $3000)
- `price1USD`: Preço do token1 em USD (ex: `1e18` para USDC = $1)

**Permissões**: Apenas `owner`

**Requisitos**: `price0USD > 0` e `price1USD > 0`

**Eventos**: `TokenPricesUpdated(PoolId indexed poolId, uint256 price0USD, uint256 price1USD)`

**Exemplo:**
```solidity
// ETH = $3000, USDC = $1
hook.setTokenPricesUSD(poolKey, 3000e18, 1e18);
```

---

#### `setPoolTickRange`

```solidity
function setPoolTickRange(
    PoolKey calldata key,
    int24 tickLower,
    int24 tickUpper
) external onlyOwner
```

**Descrição**: Configura o tick range onde a liquidez será adicionada durante o compound. **Necessário** para que o compound funcione.

**Parâmetros:**
- `key`: PoolKey da pool
- `tickLower`: Tick inferior do range
- `tickUpper`: Tick superior do range

**Permissões**: Apenas `owner`

**Requisitos**: `tickLower < tickUpper`

**Eventos**: `PoolTickRangeUpdated(PoolId indexed poolId, int24 tickLower, int24 tickUpper)`

**Exemplo:**
```solidity
// Full range
int24 tickLower = TickMath.minUsableTick(60);
int24 tickUpper = TickMath.maxUsableTick(60);
hook.setPoolTickRange(poolKey, tickLower, tickUpper);
```

---

#### `setOwner`

```solidity
function setOwner(address newOwner) external onlyOwner
```

**Descrição**: Atualiza o endereço do owner do contrato.

**Parâmetros:**
- `newOwner`: Novo endereço do owner

**Permissões**: Apenas `owner` atual

**Requisitos**: `newOwner != address(0)`

**Eventos**: `OwnerUpdated(address indexed oldOwner, address indexed newOwner)`

---

### **Funções de Compound**

#### `prepareCompound`

```solidity
function prepareCompound(PoolKey calldata key) external view returns (
    bool canCompound,
    ModifyLiquidityParams memory params,
    uint256 fees0,
    uint256 fees1
)
```

**Descrição**: Verifica condições e prepara parâmetros para execução de compound. **Use esta função antes de executar compound.**

**Parâmetros:**
- `key`: PoolKey da pool

**Retornos:**
- `canCompound`: `true` se todas as condições são atendidas
- `params`: Parâmetros para `modifyLiquidity` (vazio se `canCompound = false`)
- `fees0`: Quantidade de fees0 acumuladas
- `fees1`: Quantidade de fees1 acumuladas

**Condições para `canCompound = true`:**
1. Pool está habilitada
2. Passaram 4 horas desde último compound (ou nunca houve compound)
3. Há fees acumuladas (`fees0 > 0` ou `fees1 > 0`)
4. Preços configurados (ou fees >= 20x gas cost)
5. Tick range configurado
6. `liquidityDelta > 0`

**Exemplo:**
```solidity
(bool canCompound, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
    hook.prepareCompound(poolKey);

if (canCompound) {
    // Executar compound usando CompoundHelper
    CompoundHelper helper = new CompoundHelper(poolManager, hook);
    helper.executeCompound(poolKey, params, fees0, fees1);
}
```

---

#### `canExecuteCompound`

```solidity
function canExecuteCompound(PoolKey calldata key) external view returns (
    bool canCompound,
    string memory reason,
    uint256 timeUntilNextCompound,
    uint256 feesValueUSD,
    uint256 gasCostUSD
)
```

**Descrição**: Verifica se o compound pode ser executado e retorna informações detalhadas. Útil para keepers verificarem antes de chamar `prepareCompound`.

**Parâmetros:**
- `key`: PoolKey da pool

**Retornos:**
- `canCompound`: `true` se pode executar
- `reason`: Mensagem explicando por que não pode (vazio se `canCompound = true`)
- `timeUntilNextCompound`: Tempo restante até poder executar (em segundos, 0 se pode executar)
- `feesValueUSD`: Valor total das fees em USD
- `gasCostUSD`: Custo estimado de gas em USD

**Possíveis `reason`:**
- `"Pool not enabled"`
- `"No accumulated fees"`
- `"4 hours not elapsed"`
- `"Token prices not configured"`
- `"Fees less than 20x gas cost"`
- `""` (vazio se pode executar)

**Exemplo:**
```solidity
(bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesUSD, uint256 gasUSD) = 
    hook.canExecuteCompound(poolKey);

if (canCompound) {
    console.log("Pode executar compound!");
    console.log("Fees value:", feesUSD);
    console.log("Gas cost:", gasUSD);
} else {
    console.log("Não pode executar:", reason);
    if (timeUntilNext > 0) {
        console.log("Tempo restante:", timeUntilNext, "segundos");
    }
}
```

---

#### `executeCompound`

```solidity
function executeCompound(
    PoolKey calldata key,
    uint256 fees0,
    uint256 fees1
) external
```

**Descrição**: Reseta fees acumuladas e atualiza timestamp. **⚠️ Deve ser chamada apenas pelo CompoundHelper dentro de unlockCallback.**

**Parâmetros:**
- `key`: PoolKey da pool
- `fees0`: Quantidade de fees0 que foram reinvestidas
- `fees1`: Quantidade de fees1 que foram reinvestidas

**Permissões**: Apenas `CompoundHelper` (via unlockCallback)

**Ações:**
- Reseta `accumulatedFees0[poolId] = 0`
- Reseta `accumulatedFees1[poolId] = 0`
- Atualiza `lastCompoundTimestamp[poolId] = block.timestamp`

**Eventos**: `FeesCompounded(PoolId indexed poolId, uint256 fees0, uint256 fees1)`

**⚠️ Não chame diretamente!** Use `CompoundHelper.executeCompound()`.

---

### **Funções de Consulta**

#### `getPoolInfo`

```solidity
function getPoolInfo(PoolKey calldata key) external view returns (
    PoolConfig memory config,
    uint256 fees0,
    uint256 fees1,
    int24 tickLower,
    int24 tickUpper
)
```

**Descrição**: Obtém informações completas sobre uma pool configurada.

**Parâmetros:**
- `key`: PoolKey da pool

**Retornos:**
- `config`: Configuração da pool (enabled)
- `fees0`: Fees acumuladas em token0
- `fees1`: Fees acumuladas em token1
- `tickLower`: Tick inferior configurado
- `tickUpper`: Tick superior configurado

**Exemplo:**
```solidity
(PoolConfig memory config, uint256 fees0, uint256 fees1, int24 tickLower, int24 tickUpper) = 
    hook.getPoolInfo(poolKey);

console.log("Pool enabled:", config.enabled);
console.log("Fees0:", fees0);
console.log("Fees1:", fees1);
console.log("Tick range:", tickLower, "to", tickUpper);
```

---

#### `getAccumulatedFees`

```solidity
function getAccumulatedFees(PoolKey calldata key) external view returns (
    uint256 fees0,
    uint256 fees1
)
```

**Descrição**: Obtém apenas as fees acumuladas. Útil para keepers verificarem rapidamente.

**Parâmetros:**
- `key`: PoolKey da pool

**Retornos:**
- `fees0`: Fees acumuladas em token0
- `fees1`: Fees acumuladas em token1

**Exemplo:**
```solidity
(uint256 fees0, uint256 fees1) = hook.getAccumulatedFees(poolKey);
```

---

### **Funções de Emergência**

#### `emergencyWithdraw`

```solidity
function emergencyWithdraw(
    PoolKey calldata key,
    address to
) external onlyOwner
```

**Descrição**: Função de emergência para retirar tokens acumulados do hook. **⚠️ Apenas funciona se os tokens estiverem fisicamente no hook.**

**Parâmetros:**
- `key`: PoolKey da pool
- `to`: Endereço para onde enviar os tokens

**Permissões**: Apenas `owner`

**Requisitos**: `to != address(0)`

**Ações:**
- Transfere tokens disponíveis no hook para `to`
- Reseta fees acumuladas

**⚠️ Nota**: Fees acumuladas estão em mappings, não necessariamente no hook. Esta função só transfere tokens que estão fisicamente no hook.

**Exemplo:**
```solidity
address recipient = 0x...;
hook.emergencyWithdraw(poolKey, recipient);
```

---

## CompoundHelper

### **Funções Principais**

#### `executeCompound`

```solidity
function executeCompound(
    PoolKey memory key,
    ModifyLiquidityParams memory params,
    uint256 fees0,
    uint256 fees1
) external returns (BalanceDelta)
```

**Descrição**: Executa o compound completo. Esta é a função principal para executar compound.

**Parâmetros:**
- `key`: PoolKey da pool
- `params`: Parâmetros de liquidez (obtidos de `prepareCompound`)
- `fees0`: Quantidade de fees0 (obtida de `prepareCompound`)
- `fees1`: Quantidade de fees1 (obtida de `prepareCompound`)

**Permissões**: Apenas `deployer` (quem deployou o helper)

**Retornos:**
- `BalanceDelta`: Delta de balance após compound

**Fluxo:**
1. Chama `poolManager.unlock(callbackData)`
2. `PoolManager` chama `unlockCallback`
3. `unlockCallback`:
   - Chama `poolManager.modifyLiquidity()` → adiciona liquidez
   - Settle/take tokens do `deployer`
   - Chama `hook.executeCompound()` → reseta fees

**⚠️ Requisitos:**
- `deployer` deve ter aprovação para tokens (se necessário)
- `deployer` deve ter saldo suficiente para settle

**Exemplo:**
```solidity
// 1. Preparar compound
(bool canCompound, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
    hook.prepareCompound(poolKey);

if (canCompound) {
    // 2. Aprovar helper (se necessário)
    token0.approve(address(helper), type(uint256).max);
    token1.approve(address(helper), type(uint256).max);
    
    // 3. Executar compound
    CompoundHelper helper = new CompoundHelper(poolManager, hook);
    BalanceDelta delta = helper.executeCompound(poolKey, params, fees0, fees1);
}
```

---

## 📊 **Constantes**

### `COMPOUND_INTERVAL`
```solidity
uint256 public constant COMPOUND_INTERVAL = 4 hours; // 14400 segundos
```

Intervalo mínimo entre compounds.

### `MIN_FEES_MULTIPLIER`
```solidity
uint256 public constant MIN_FEES_MULTIPLIER = 20;
```

Multiplicador mínimo: fees devem valer pelo menos 20x o custo de gas.

### `FEE_RECIPIENT`
```solidity
address public constant FEE_RECIPIENT = 0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c;
```

Endereço que recebe 10% das fees quando liquidez é removida.

---

## 📝 **Eventos**

### `FeesCompounded`
```solidity
event FeesCompounded(
    PoolId indexed poolId,
    uint256 amount0,
    uint256 amount1
);
```

Emitido quando compound é executado.

### `PoolConfigUpdated`
```solidity
event PoolConfigUpdated(
    PoolId indexed poolId,
    bool enabled
);
```

Emitido quando configuração da pool é atualizada.

### `TokenPricesUpdated`
```solidity
event TokenPricesUpdated(
    PoolId indexed poolId,
    uint256 price0USD,
    uint256 price1USD
);
```

Emitido quando preços dos tokens são atualizados.

### `PoolTickRangeUpdated`
```solidity
event PoolTickRangeUpdated(
    PoolId indexed poolId,
    int24 tickLower,
    int24 tickUpper
);
```

Emitido quando tick range é atualizado.

### `OwnerUpdated`
```solidity
event OwnerUpdated(
    address indexed oldOwner,
    address indexed newOwner
);
```

Emitido quando owner é atualizado.

---

## 🔍 **Códigos de Erro**

### `"Not owner"`
- **Quando**: Função protegida por `onlyOwner` é chamada por não-owner
- **Solução**: Use o endereço do owner

### `"Invalid owner"`
- **Quando**: Tentativa de setar owner como `address(0)`
- **Solução**: Use um endereço válido

### `"Invalid tick range"`
- **Quando**: `tickLower >= tickUpper`
- **Solução**: Certifique-se de que `tickLower < tickUpper`

### `"Token0 price must be > 0"`
- **Quando**: Tentativa de setar preço como 0
- **Solução**: Use um preço válido > 0

### `"Token1 price must be > 0"`
- **Quando**: Tentativa de setar preço como 0
- **Solução**: Use um preço válido > 0

### `"Invalid address"`
- **Quando**: Tentativa de usar `address(0)` em `emergencyWithdraw`
- **Solução**: Use um endereço válido

---

## 📚 **Exemplos Completos**

### **Exemplo 1: Configuração Completa de Pool**

```solidity
// 1. Habilitar pool
hook.setPoolConfig(poolKey, true);

// 2. Configurar preços (ETH = $3000, USDC = $1)
hook.setTokenPricesUSD(poolKey, 3000e18, 1e18);

// 3. Configurar tick range (full range)
int24 tickLower = TickMath.minUsableTick(60);
int24 tickUpper = TickMath.maxUsableTick(60);
hook.setPoolTickRange(poolKey, tickLower, tickUpper);
```

### **Exemplo 2: Verificar e Executar Compound**

```solidity
// 1. Verificar se pode executar
(bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesUSD, uint256 gasUSD) = 
    hook.canExecuteCompound(poolKey);

if (!canCompound) {
    console.log("Não pode executar:", reason);
    if (timeUntilNext > 0) {
        console.log("Tempo restante:", timeUntilNext / 3600, "horas");
    }
    return;
}

// 2. Preparar compound
(bool canPrepare, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
    hook.prepareCompound(poolKey);

if (!canPrepare) {
    console.log("Não pode preparar compound");
    return;
}

// 3. Aprovar helper
token0.approve(address(helper), type(uint256).max);
token1.approve(address(helper), type(uint256).max);

// 4. Executar compound
CompoundHelper helper = new CompoundHelper(poolManager, hook);
try helper.executeCompound(poolKey, params, fees0, fees1) returns (BalanceDelta delta) {
    console.log("Compound executado com sucesso!");
    console.log("Delta amount0:", delta.amount0());
    console.log("Delta amount1:", delta.amount1());
} catch Error(string memory reason) {
    console.log("Erro:", reason);
}
```

---

**Última atualização**: 2025-01-05

