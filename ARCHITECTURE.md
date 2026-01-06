# 🏗️ Arquitetura do AutoCompoundHook

**Versão**: 1.0  
**Última atualização**: 2025-01-05

---

## 📋 **Visão Geral**

O `AutoCompoundHook` é um sistema de auto-compound para Uniswap V4 que automaticamente reinveste taxas acumuladas de volta na pool de liquidez, maximizando retornos para provedores de liquidez.

---

## 🎯 **Componentes Principais**

### 1. **AutoCompoundHook** (`src/hooks/AutoCompoundHook.sol`)

**Responsabilidades:**
- Acumular fees durante swaps
- Verificar condições para compound
- Preparar parâmetros para compound
- Gerenciar configurações por pool
- Calcular thresholds e valores em USD

**Características:**
- Herda de `BaseHook` (Uniswap V4)
- Suporta múltiplas pools simultaneamente
- Configuração por pool (enabled, tick range, preços)
- Acumulação de fees em mappings

### 2. **CompoundHelper** (`src/helpers/CompoundHelper.sol`)

**Responsabilidades:**
- Executar compound via `unlock` callback
- Gerenciar settle/take de tokens
- Interagir com PoolManager durante unlock
- Chamar `hook.executeCompound()` para resetar fees

**Características:**
- Implementa `IUnlockCallback`
- Usa `deployer` como payer para settle
- Gerencia o fluxo completo de compound

### 3. **PoolManager** (Uniswap V4)

**Responsabilidades:**
- Gerenciar pools de liquidez
- Processar swaps e modificar liquidez
- Chamar callbacks do hook
- Gerenciar estado da pool

### 4. **Keeper** (Externo - `script/AutoCompoundKeeper.s.sol`)

**Responsabilidades:**
- Verificar periodicamente condições de compound
- Executar compound quando condições são atendidas
- Monitorar estado das pools

**Características:**
- Script Foundry executável
- Pode ser automatizado via cron
- Verifica antes de executar (economiza gas)

---

## 🔄 **Fluxo de Dados**

### **Fluxo 1: Acumulação de Fees**

```
Swap → PoolManager.swap()
  ↓
Hook.afterSwap() (callback)
  ↓
Calcular fees (0.3% do swap)
  ↓
Acumular em mappings:
  - accumulatedFees0[poolId] += fee0
  - accumulatedFees1[poolId] += fee1
```

### **Fluxo 2: Execução de Compound**

```
Keeper verifica condições
  ↓
hook.canExecuteCompound() → verifica:
  - Pool enabled?
  - 4 horas passaram?
  - Fees >= 20x gas cost?
  ↓
hook.prepareCompound() → prepara:
  - Calcula liquidityDelta
  - Cria ModifyLiquidityParams
  ↓
CompoundHelper.executeCompound()
  ↓
PoolManager.unlock()
  ↓
CompoundHelper.unlockCallback()
  ├─ poolManager.modifyLiquidity() → adiciona liquidez
  ├─ settle/take tokens do deployer
  └─ hook.executeCompound() → reseta fees
```

---

## 📊 **Estrutura de Dados**

### **PoolConfig**
```solidity
struct PoolConfig {
    bool enabled; // Se auto-compound está habilitado
}
```

### **Mappings Principais**
- `poolConfigs[PoolId]` → Configuração da pool
- `accumulatedFees0[PoolId]` → Fees acumuladas em token0
- `accumulatedFees1[PoolId]` → Fees acumuladas em token1
- `poolTickLower[PoolId]` → Tick inferior para compound
- `poolTickUpper[PoolId]` → Tick superior para compound
- `lastCompoundTimestamp[PoolId]` → Último compound
- `token0PriceUSD[PoolId]` → Preço token0 em USD
- `token1PriceUSD[PoolId]` → Preço token1 em USD

---

## 🔐 **Segurança e Controle de Acesso**

### **Modifiers**
- `onlyOwner`: Apenas owner pode configurar pools

### **Verificações de Segurança**
- Validação de endereços (zero address)
- Verificação de tick range válido
- Proteção contra overflow (SafeCast)
- Verificação de limites de liquidez

### **Proteções**
- Intervalo mínimo de 4 horas entre compounds
- Threshold de 20x custo de gas
- Verificação de liquidez máxima por tick

---

## 🔄 **Ciclo de Vida de uma Pool**

1. **Inicialização**
   - Pool criada com hook
   - `afterInitialize` salva configuração padrão

2. **Configuração** (Owner)
   - `setPoolConfig(poolKey, true)` → habilita
   - `setTokenPricesUSD(poolKey, price0, price1)` → configura preços
   - `setPoolTickRange(poolKey, tickLower, tickUpper)` → configura range

3. **Acumulação de Fees**
   - Cada swap acumula fees automaticamente
   - Fees armazenadas em mappings

4. **Compound**
   - Keeper verifica condições periodicamente
   - Quando condições atendidas, executa compound
   - Fees reinvestidas como liquidez
   - Fees resetadas, timestamp atualizado

5. **Remoção de Liquidez**
   - `afterRemoveLiquidity` captura 10% das fees
   - Converte para USDC
   - Envia para FEE_RECIPIENT

---

## 🎨 **Padrões de Design**

### **1. Hook Pattern (Uniswap V4)**
- Hook intercepta callbacks do PoolManager
- Permite lógica customizada em pontos específicos

### **2. Helper Pattern**
- `CompoundHelper` encapsula lógica complexa de unlock
- Separa responsabilidades (Hook vs Helper)

### **3. Keeper Pattern**
- Script externo monitora e executa ações
- Permite automação sem modificar contratos

### **4. Mapping Pattern**
- Configurações e estado por pool
- Permite múltiplas pools simultaneamente

---

## 📈 **Fluxo de Compound Detalhado**

### **Passo a Passo:**

1. **Verificação** (`canExecuteCompound`)
   ```solidity
   - Pool enabled? → Se não, retorna false
   - Fees acumuladas? → Se não, retorna false
   - 4 horas passaram? → Se não, retorna false + timeUntilNext
   - Preços configurados? → Se não, retorna false
   - Fees >= 20x gas cost? → Se não, retorna false
   - Retorna true se todas condições atendidas
   ```

2. **Preparação** (`prepareCompound`)
   ```solidity
   - Verifica condições (igual canExecuteCompound)
   - Obtém fees acumuladas
   - Calcula liquidityDelta usando _calculateLiquidityFromAmounts
   - Verifica se liquidityDelta > 0
   - Cria ModifyLiquidityParams
   - Retorna params + fees
   ```

3. **Execução** (`CompoundHelper.executeCompound`)
   ```solidity
   - Chama poolManager.unlock(callbackData)
   - PoolManager chama unlockCallback
   - unlockCallback:
     a. Chama poolManager.modifyLiquidity() → adiciona liquidez
     b. Obtém callerDelta e feesAccrued
     c. Settle tokens do deployer (se necessário)
     d. Take tokens do deployer (se necessário)
     e. Chama hook.executeCompound() → reseta fees
   ```

---

## 🔧 **Interações entre Contratos**

```
┌─────────────────┐
│   PoolManager   │
│  (Uniswap V4)   │
└────────┬─────────┘
         │
         │ callbacks
         │
         ▼
┌─────────────────┐
│ AutoCompoundHook│
│   (Hook)        │
└────────┬─────────┘
         │
         │ prepareCompound()
         │ executeCompound()
         │
         ▼
┌─────────────────┐
│CompoundHelper   │
│  (Helper)       │
└────────┬─────────┘
         │
         │ unlock()
         │
         ▼
┌─────────────────┐
│   PoolManager   │
│  (Uniswap V4)   │
└─────────────────┘
```

---

## 📝 **Decisões de Arquitetura**

### **1. Por que usar CompoundHelper?**
- Uniswap V4 requer `unlock` para modificar liquidez
- `unlock` requer callback (`IUnlockCallback`)
- Hook não pode ser o callback (seria circular)
- Helper separa responsabilidades

### **2. Por que fees são acumuladas em mappings?**
- Fees não estão fisicamente no hook
- Mappings rastreiam fees que serão reinvestidas
- Permite calcular compound sem transferir tokens

### **3. Por que verificar 20x gas cost?**
- Garante que compound é lucrativo
- Previne compounds que custam mais que valem
- Threshold dinâmico baseado em gas atual

### **4. Por que intervalo de 4 horas?**
- Previne compounds excessivos
- Permite acumular fees suficientes
- Balanceia frequência vs custo de gas

---

## 🔍 **Pontos de Entrada (Callbacks)**

### **afterInitialize**
- Quando: Pool é inicializada
- Ação: Salva configuração padrão (enabled = true)

### **afterSwap**
- Quando: Swap é executado
- Ação: Calcula e acumula fees

### **afterAddLiquidity**
- Quando: Liquidez é adicionada
- Ação: Salva tick range se não configurado

### **afterRemoveLiquidity**
- Quando: Liquidez é removida
- Ação: Captura 10% das fees, converte para USDC, envia para FEE_RECIPIENT

---

## 🎯 **Casos de Uso**

### **Caso 1: Pool Simples (WETH/USDC)**
1. Criar pool com hook
2. Configurar preços (WETH = $3000, USDC = $1)
3. Configurar tick range (full range)
4. Adicionar liquidez
5. Swaps geram fees automaticamente
6. Keeper executa compound a cada 4h (se condições atendidas)

### **Caso 2: Múltiplas Pools**
- Cada pool tem configuração independente
- Fees acumuladas separadamente
- Compound executado independentemente

### **Caso 3: Pool Concentrada**
- Tick range configurado para range específico
- Compound adiciona liquidez no mesmo range
- Maximiza eficiência de capital

---

## 📚 **Referências**

- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Uniswap V4 Hooks](https://docs.uniswap.org/contracts/v4/concepts/hooks)
- [Foundry Book](https://book.getfoundry.sh/)

---

**Última atualização**: 2025-01-05

