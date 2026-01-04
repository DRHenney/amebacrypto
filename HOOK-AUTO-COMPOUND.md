# AutoCompoundHook - Uniswap v4 Hook

## Visão Geral

O `AutoCompoundHook` é um hook para Uniswap v4 que automaticamente reinveste taxas acumuladas de volta na pool de liquidez, maximizando os retornos para os provedores de liquidez.

## Funcionalidades Principais

### 1. Acumulação Automática de Taxas
- As taxas geradas pelos swaps são acumuladas automaticamente
- Suporte para múltiplas pools simultaneamente

### 2. Compound Automático com Condições
O compound é executado automaticamente quando:
- **Intervalo de tempo**: Passaram pelo menos **4 horas** desde o último compound
- **Threshold de rentabilidade**: As taxas acumuladas valem pelo menos **20x o custo de gas** em USD

### 3. Cálculo Automático de Threshold
- O threshold é calculado dinamicamente baseado no custo atual de gas
- Não requer configuração manual de valores fixos
- Usa preços dos tokens em USD para calcular o valor total das fees

## Como Funciona

### Para Keepers (Executores)

**⚠️ IMPORTANTE**: A função `checkAndCompound()` foi descontinuada. Use o novo padrão:

1. Primeiro, verifique se pode fazer compound:
```solidity
(bool canCompound, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
    hook.prepareCompound(key);
```

2. Se `canCompound` for `true`, execute o compound usando `CompoundHelper`:
```solidity
CompoundHelper helper = new CompoundHelper(poolManager, hook);
BalanceDelta delta = helper.executeCompound(key, params, fees0, fees1);
```

**Alternativa antiga (mantida para compatibilidade, mas não executa compound):**
```solidity
function checkAndCompound(PoolKey calldata key) external returns (bool executed)
```
**Nota**: Esta função sempre retorna `false`. Use `prepareCompound` + `CompoundHelper.executeCompound` em vez disso.

### Verificação Antes de Executar

Antes de chamar `checkAndCompound()`, os keepers podem verificar se o compound pode ser executado:

```solidity
function canExecuteCompound(PoolKey calldata key) external view returns (
    bool canCompound,
    string memory reason,
    uint256 timeUntilNextCompound,
    uint256 feesValueUSD,
    uint256 gasCostUSD
)
```

**Retornos:**
- `canCompound`: `true` se todas as condições são atendidas
- `reason`: Mensagem explicando por que não pode executar (se aplicável)
- `timeUntilNextCompound`: Tempo restante até poder fazer compound (em segundos)
- `feesValueUSD`: Valor das fees acumuladas em USD
- `gasCostUSD`: Custo estimado de gas em USD

## Configuração

### Habilitar/Desabilitar Pool

```solidity
function setPoolConfig(PoolKey calldata key, bool enabled) external onlyOwner
```

### Configurar Preços dos Tokens (Necessário)

Para que o hook calcule corretamente o valor das fees em USD, é necessário configurar os preços dos tokens:

```solidity
function setTokenPricesUSD(
    PoolKey calldata key,
    uint256 price0USD,  // Preço do token0 em USD (ex: 3000 = $3000 para ETH)
    uint256 price1USD   // Preço do token1 em USD (ex: 1 = $1 para USDC)
) external onlyOwner
```

### Configurar Tick Range (Necessário para Compound)

O tick range define onde a liquidez será adicionada durante o compound:

```solidity
function setPoolTickRange(
    PoolKey calldata key,
    int24 tickLower,
    int24 tickUpper
) external onlyOwner
```

## Constantes

- `COMPOUND_INTERVAL = 4 hours`: Intervalo mínimo entre compounds
- `MIN_FEES_MULTIPLIER = 20`: Multiplicador mínimo (fees devem ser >= 20x o custo de gas)

## Fluxo de Trabalho

1. **Acumulação**: As taxas são acumuladas automaticamente durante os swaps
2. **Verificação**: Keeper verifica `canExecuteCompound()` periodicamente
3. **Preparação**: Quando condições são atendidas, keeper chama `prepareCompound()` para obter parâmetros
4. **Execução**: Keeper usa `CompoundHelper.executeCompound()` para executar o compound via unlock
5. **Compound**: As taxas são reinvestidas como liquidez na pool

## Funções Principais

### Para Keepers
- `prepareCompound(PoolKey)`: Prepara parâmetros para compound (novo padrão)
- `canExecuteCompound(PoolKey)`: Verifica se pode executar compound
- `getAccumulatedFees(PoolKey)`: Obtém fees acumuladas
- `checkAndCompound(PoolKey)`: ⚠️ Descontinuada - sempre retorna false

### Para Administradores
- `setPoolConfig(PoolKey, bool)`: Habilita/desabilita pool
- `setTokenPricesUSD(PoolKey, uint256, uint256)`: Configura preços dos tokens
- `setPoolTickRange(PoolKey, int24, int24)`: Configura tick range
- `setOwner(address)`: Atualiza o owner

## Eventos

- `FeesCompounded(PoolId indexed poolId, uint256 amount0, uint256 amount1)`: Emitido quando compound é executado

## Segurança

- Apenas o `owner` pode configurar pools
- Verificação de rentabilidade (20x custo de gas) previne compounds não lucrativos
- Intervalo mínimo de 4 horas previne compounds excessivos

## Exemplo de Uso para Keeper

```solidity
// 1. Verificar se pode executar (opcional, mas recomendado)
(bool canCompound, string memory reason, , uint256 feesUSD, uint256 gasUSD) = 
    hook.canExecuteCompound(poolKey);

if (canCompound) {
    // 2. Preparar compound para obter parâmetros
    (bool canPrepare, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
        hook.prepareCompound(poolKey);
    
    if (canPrepare) {
        // 3. Executar compound via CompoundHelper
        CompoundHelper helper = new CompoundHelper(poolManager, hook);
        try helper.executeCompound(poolKey, params, fees0, fees1) returns (BalanceDelta delta) {
            // Compound executado com sucesso!
            // Fees foram resetadas e liquidez foi adicionada
        } catch {
            // Tratar erro (pode ser por falta de saldo, overflow, etc.)
        }
    }
} else {
    // Log do motivo (reason, feesUSD, gasUSD)
}
```

