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

Os keepers devem chamar `checkAndCompound()` periodicamente (recomendado a cada 4 horas):

```solidity
function checkAndCompound(PoolKey calldata key) external returns (bool executed)
```

**Retorno:**
- `true`: Compound foi executado com sucesso
- `false`: Condições não foram atendidas (intervalo de 4h ou fees insuficientes)

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
3. **Execução**: Quando condições são atendidas, keeper chama `checkAndCompound()`
4. **Compound**: As taxas são reinvestidas como liquidez na pool

## Funções Principais

### Para Keepers
- `checkAndCompound(PoolKey)`: Executa compound se condições atendidas
- `canExecuteCompound(PoolKey)`: Verifica se pode executar compound
- `getAccumulatedFees(PoolKey)`: Obtém fees acumuladas

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
// Verificar se pode executar
(bool canCompound, string memory reason, , uint256 feesUSD, uint256 gasUSD) = 
    hook.canExecuteCompound(poolKey);

if (canCompound) {
    // Executar compound
    bool executed = hook.checkAndCompound(poolKey);
    if (executed) {
        // Compound executado com sucesso
    }
} else {
    // Log do motivo (reason, feesUSD, gasUSD)
}
```

