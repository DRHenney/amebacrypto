# 🔧 Troubleshooting - AutoCompoundHook

**Versão**: 1.0  
**Última atualização**: 2025-01-05

---

## 📋 **Índice**

- [Problemas de Deploy](#problemas-de-deploy)
- [Problemas de Configuração](#problemas-de-configuração)
- [Problemas de Compound](#problemas-de-compound)
- [Problemas de Fees](#problemas-de-fees)
- [Problemas de Gas](#problemas-de-gas)
- [Comandos Úteis](#comandos-úteis)

---

## 🚀 **Problemas de Deploy**

### **Erro: "Hook address mismatch"**

**Sintoma:**
```
Error: Hook address mismatch
```

**Causa**: O hook foi deployado em um endereço diferente do esperado pelo HookMiner.

**Solução:**
1. Verifique se está usando o mesmo `salt` do HookMiner
2. Verifique se as permissões do hook estão corretas
3. Re-deploy usando o script correto

---

### **Erro: "Invalid owner"**

**Sintoma:**
```
Error: Invalid owner
```

**Causa**: Tentativa de criar hook com `address(0)` como owner.

**Solução:**
```solidity
// Use um endereço válido
address owner = 0x...; // Seu endereço
hook = new AutoCompoundHook(poolManager, owner);
```

---

## ⚙️ **Problemas de Configuração**

### **Problema: Pool não está habilitada**

**Sintoma:**
- Fees não acumulam
- `canExecuteCompound` retorna `false` com reason "Pool not enabled"

**Solução:**
```solidity
hook.setPoolConfig(poolKey, true);
```

**Verificação:**
```solidity
(PoolConfig memory config,,,) = hook.getPoolInfo(poolKey);
assertTrue(config.enabled);
```

---

### **Problema: Preços não configurados**

**Sintoma:**
- `canExecuteCompound` retorna `false` com reason "Token prices not configured"
- `feesValueUSD` retorna 0

**Solução:**
```solidity
// Configurar preços (exemplo: ETH = $3000, USDC = $1)
hook.setTokenPricesUSD(poolKey, 3000e18, 1e18);
```

**Verificação:**
```solidity
(, uint256 feesUSD, uint256 gasUSD) = hook.canExecuteCompound(poolKey);
// feesUSD deve ser > 0 se preços configurados
```

---

### **Problema: Tick range não configurado**

**Sintoma:**
- `prepareCompound` retorna `false`
- `canExecuteCompound` pode retornar `true`, mas `prepareCompound` falha

**Solução:**
```solidity
int24 tickLower = TickMath.minUsableTick(60);
int24 tickUpper = TickMath.maxUsableTick(60);
hook.setPoolTickRange(poolKey, tickLower, tickUpper);
```

**Verificação:**
```solidity
(,,, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
assertTrue(tickLower != 0 || tickUpper != 0);
```

---

### **Erro: "Invalid tick range"**

**Sintoma:**
```
Error: Invalid tick range
```

**Causa**: `tickLower >= tickUpper`

**Solução:**
```solidity
// Certifique-se de que tickLower < tickUpper
int24 tickLower = -887220;
int24 tickUpper = 887220;
require(tickLower < tickUpper, "Invalid range");
hook.setPoolTickRange(poolKey, tickLower, tickUpper);
```

---

## 🔄 **Problemas de Compound**

### **Problema: Compound não executa - "4 hours not elapsed"**

**Sintoma:**
- `canExecuteCompound` retorna `false` com reason "4 hours not elapsed"
- `timeUntilNextCompound > 0`

**Causa**: Ainda não passaram 4 horas desde o último compound.

**Solução:**
- **Aguardar**: Espere o tempo necessário
- **Verificar timestamp**: 
  ```solidity
  uint256 lastCompound = hook.lastCompoundTimestamp(poolId);
  uint256 timeElapsed = block.timestamp - lastCompound;
  uint256 timeRemaining = 4 hours - timeElapsed;
  ```

**Nota**: Se `lastCompoundTimestamp` é 0, significa que nunca houve compound, então pode executar.

---

### **Problema: Compound não executa - "Fees less than 20x gas cost"**

**Sintoma:**
- `canExecuteCompound` retorna `false` com reason "Fees less than 20x gas cost"
- `feesValueUSD < gasCostUSD * 20`

**Causa**: Fees acumuladas não valem o suficiente para justificar o custo de gas.

**Solução:**
- **Aguardar mais swaps**: Acumule mais fees
- **Verificar preços**: Certifique-se de que preços estão corretos
- **Verificar gas cost**: Pode estar alto, aguarde

**Verificação:**
```solidity
(, string memory reason,, uint256 feesUSD, uint256 gasUSD) = 
    hook.canExecuteCompound(poolKey);
console.log("Fees USD:", feesUSD);
console.log("Gas USD:", gasUSD);
console.log("Necessário:", gasUSD * 20);
```

---

### **Problema: Compound não executa - "No accumulated fees"**

**Sintoma:**
- `canExecuteCompound` retorna `false` com reason "No accumulated fees"
- `accumulatedFees0` e `accumulatedFees1` são 0

**Causa**: Não há fees acumuladas ainda.

**Solução:**
- **Execute swaps**: Fees são acumuladas durante swaps
- **Verifique se pool está habilitada**: Fees só acumulam se pool está enabled
- **Verifique se hook está sendo chamado**: Certifique-se de que swaps passam pelo hook

**Verificação:**
```solidity
(uint256 fees0, uint256 fees1) = hook.getAccumulatedFees(poolKey);
console.log("Fees0:", fees0);
console.log("Fees1:", fees1);
```

---

### **Problema: `prepareCompound` retorna `liquidityDelta = 0`**

**Sintoma:**
- `prepareCompound` retorna `canCompound = false`
- `liquidityDelta` é 0 ou negativo

**Causa**: Fees são muito pequenas ou preço está fora do range.

**Solução:**
- **Acumule mais fees**: Execute mais swaps
- **Verifique tick range**: Certifique-se de que range inclui preço atual
- **Use full range**: Para máxima compatibilidade

**Verificação:**
```solidity
(, ModifyLiquidityParams memory params,,) = hook.prepareCompound(poolKey);
console.log("Liquidity Delta:", params.liquidityDelta);
```

---

### **Erro: "ERC20: transfer amount exceeds balance"**

**Sintoma:**
```
Error: ERC20: transfer amount exceeds balance
```

**Causa**: `deployer` não tem saldo suficiente para settle durante compound.

**Solução:**
- **Aprovar tokens**: Certifique-se de que `deployer` aprovou `CompoundHelper`
- **Verificar saldo**: Certifique-se de que `deployer` tem tokens suficientes
- **Verificar fees**: Fees podem estar maiores que o saldo disponível

**Verificação:**
```solidity
uint256 balance0 = token0.balanceOf(deployer);
uint256 balance1 = token1.balanceOf(deployer);
(uint256 fees0, uint256 fees1) = hook.getAccumulatedFees(poolKey);
// balance0 e balance1 devem ser >= fees0 e fees1
```

---

### **Erro: "ERC20: transfer amount exceeds allowance"**

**Sintoma:**
```
Error: ERC20: transfer amount exceeds allowance
```

**Causa**: `deployer` não aprovou `CompoundHelper` para gastar tokens.

**Solução:**
```solidity
token0.approve(address(compoundHelper), type(uint256).max);
token1.approve(address(compoundHelper), type(uint256).max);
```

---

### **Erro: "SafeCastOverflow"**

**Sintoma:**
```
Error: SafeCastOverflow()
```

**Causa**: Tentativa de adicionar liquidez que excede limites seguros.

**Solução:**
- **Reduza fees**: Execute compound com fees menores
- **Verifique limites**: O hook verifica limites automaticamente, mas pode falhar se muito próximo

---

## 💰 **Problemas de Fees**

### **Problema: Fees não acumulam durante swaps**

**Sintoma:**
- Swaps executam, mas `accumulatedFees0` e `accumulatedFees1` não aumentam

**Causa:**
- Pool não está habilitada
- Hook não está sendo chamado
- Swaps não estão passando pelo hook

**Solução:**
1. **Verificar se pool está habilitada:**
   ```solidity
   (PoolConfig memory config,,,) = hook.getPoolInfo(poolKey);
   assertTrue(config.enabled);
   ```

2. **Verificar se hook está na pool:**
   ```solidity
   assertEq(address(poolKey.hooks), address(hook));
   ```

3. **Verificar se swaps estão usando a pool correta**

---

### **Problema: Fees acumulam apenas em um token**

**Sintoma:**
- `accumulatedFees0 > 0` mas `accumulatedFees1 = 0` (ou vice-versa)

**Causa**: Swaps estão apenas em uma direção.

**Solução:**
- **Execute swaps alternados**: Faça swaps em ambas direções
- **Verifique direção dos swaps**: Fees são acumuladas no token de entrada

**Explicação:**
- Swap token0 → token1: fees acumulam em token0
- Swap token1 → token0: fees acumulam em token1

---

## ⛽ **Problemas de Gas**

### **Problema: Gas muito alto**

**Sintoma:**
- Transações custam muito gas
- Compound não é lucrativo

**Solução:**
- **Aguarde gas mais baixo**: Monitore `block.basefee`
- **Acumule mais fees**: Execute mais swaps antes de compound
- **Otimize keeper**: Execute apenas quando realmente necessário

---

### **Problema: Estimativa de gas incorreta**

**Sintoma:**
- `gasCostUSD` calculado incorretamente
- Compound não executa mesmo com fees suficientes

**Causa**: `_calculateGasCostUSD` usa estimativa fixa.

**Solução:**
- **Ajuste estimativa**: Modifique `estimatedGasLimit` em `_calculateGasCostUSD`
- **Use preço real**: O hook usa `block.basefee * 2`, pode ajustar

---

## 🛠️ **Comandos Úteis**

### **Verificar Estado da Pool**

```bash
bash verificar-fees-atualizada.sh
```

### **Verificar Estado Completo**

```bash
bash verificar-estado-pool.sh
```

### **Executar Compound Manualmente**

```bash
bash executar-compound-atualizado.sh
```

### **Executar Keeper**

```bash
bash executar-keeper-compound.sh
```

### **Verificar Logs do Keeper**

```bash
tail -f /tmp/compound-keeper.log
```

---

## 📊 **Diagnóstico Rápido**

### **Checklist de Diagnóstico**

1. **Pool habilitada?**
   ```solidity
   (PoolConfig memory config,,,) = hook.getPoolInfo(poolKey);
   // config.enabled deve ser true
   ```

2. **Preços configurados?**
   ```solidity
   (,,, uint256 feesUSD, uint256 gasUSD) = hook.canExecuteCompound(poolKey);
   // feesUSD deve ser > 0
   ```

3. **Tick range configurado?**
   ```solidity
   (,,, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
   // tickLower e tickUpper devem ser != 0
   ```

4. **Fees acumuladas?**
   ```solidity
   (uint256 fees0, uint256 fees1) = hook.getAccumulatedFees(poolKey);
   // fees0 ou fees1 devem ser > 0
   ```

5. **Condições atendidas?**
   ```solidity
   (bool canCompound, string memory reason,,,) = hook.canExecuteCompound(poolKey);
   // canCompound deve ser true
   // reason deve ser ""
   ```

---

## 🔍 **Debug Avançado**

### **Verificar Fees em Tempo Real**

```solidity
function debugFees(PoolKey memory poolKey) external view {
    (uint256 fees0, uint256 fees1) = hook.getAccumulatedFees(poolKey);
    (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesUSD, uint256 gasUSD) = 
        hook.canExecuteCompound(poolKey);
    
    console.log("Fees0:", fees0);
    console.log("Fees1:", fees1);
    console.log("Can compound:", canCompound);
    console.log("Reason:", reason);
    console.log("Time until next:", timeUntilNext);
    console.log("Fees USD:", feesUSD);
    console.log("Gas USD:", gasUSD);
}
```

### **Verificar Configuração Completa**

```solidity
function debugConfig(PoolKey memory poolKey) external view {
    (PoolConfig memory config, uint256 fees0, uint256 fees1, int24 tickLower, int24 tickUpper) = 
        hook.getPoolInfo(poolKey);
    
    console.log("Pool enabled:", config.enabled);
    console.log("Fees0:", fees0);
    console.log("Fees1:", fees1);
    console.log("Tick lower:", tickLower);
    console.log("Tick upper:", tickUpper);
    console.log("Last compound:", hook.lastCompoundTimestamp(poolKey.toId()));
}
```

---

## 📖 **Problemas Históricos Resolvidos**

### **Problema: `prepareCompound` retorna `liquidityDelta = 0`**

**Causa**: Fees muito pequenas comparadas com liquidez existente.

**Solução**: 
- Execute mais swaps para acumular fees maiores
- O sistema está funcionando corretamente - está prevenindo compounds não lucrativos
- Para testar compound real, você precisa de fees significativas (pelo menos 0.01-0.1% do valor da liquidez)

**Status**: ✅ Resolvido - Comportamento esperado do sistema

---

### **Problema: Intervalo de 4 horas**

**Explicação**: O intervalo de 4 horas só se aplica DEPOIS do primeiro compound. Se nunca executou compound, pode executar imediatamente.

**Código relevante**:
```solidity
uint256 lastCompound = lastCompoundTimestamp[poolId];
if (lastCompound > 0) {  // Só verifica se JÁ EXECUTOU antes
    uint256 timeElapsed = block.timestamp - lastCompound;
    if (timeElapsed < COMPOUND_INTERVAL) {
        return (false, "4 hours not elapsed", ...);
    }
}
// Se lastCompound == 0 (nunca executou), não verifica intervalo
```

**Status**: ✅ Documentado - Comportamento esperado

---

### **Problema: "Only PoolManager via unlock"**

**Causa**: Hook deployado tinha verificação restritiva que foi removida.

**Solução**: 
- Removida verificação `require(msg.sender == address(poolManager))` do `executeCompound`
- Novo deploy do hook necessário

**Status**: ✅ Resolvido - Código atualizado

---

### **Problema: Regra de 10x removida**

**Histórico**: Havia uma proteção que impedia compound quando liquidez atual era 10x ou mais que liquidez calculada das fees.

**Solução**: Proteção removida do código.

**Status**: ✅ Resolvido - Proteção removida

---

## 📚 **Recursos Adicionais**

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Entender arquitetura
- [API-REFERENCE.md](./API-REFERENCE.md) - Referência de funções
- [INTEGRATION-GUIDE.md](./INTEGRATION-GUIDE.md) - Guia de integração
- [README-KEEPER.md](./README-KEEPER.md) - Troubleshooting do keeper
- [HISTORICO.md](./HISTORICO.md) - Documentos históricos detalhados

---

**Última atualização**: 2025-01-05

