# 📋 Instruções: Configurar CompoundHelper e Executar Compound

## ✅ O que foi implementado

O hook agora suporta usar **fees reais** do PoolManager em vez de fees estimadas. Para isso, é necessário configurar o endereço do `CompoundHelper` no hook.

## 🔧 Passo 1: Executar o Script

Execute o script que configura o CompoundHelper e executa o compound:

```bash
bash executar-compound-real-fees.sh
```

Ou manualmente:

```bash
forge script script/ExecuteCompoundWithRealFees.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## 📝 O que o script faz

1. **Verifica se CompoundHelper já está configurado**
   - Se sim, usa o existente
   - Se não, deploya um novo e configura no hook

2. **Configura o CompoundHelper no hook**
   - Chama `hook.setCompoundHelper(poolKey, address(helper))`
   - Isso permite que `prepareCompound()` use fees reais

3. **Prepara o compound**
   - `prepareCompound()` agora usa fees reais da posição quando o helper está configurado
   - Calcula `liquidityDelta` baseado nas fees reais

4. **Executa o compound**
   - Usa `CompoundHelper.executeCompound()`
   - O helper simplificado agora usa apenas `callerDelta` e `feesAccrued` do `modifyLiquidity`

## 🎯 Diferenças: Fees Reais vs Estimadas

### Antes (Fees Estimadas):
- Hook acumula fees estimadas em `accumulatedFees0/1`
- `prepareCompound()` usa essas estimativas
- Pode não corresponder às fees reais do PoolManager

### Agora (Fees Reais):
- `prepareCompound()` calcula fees reais da posição usando `getPositionInfo` e `getFeeGrowthInside`
- Usa as fees reais que o PoolManager tem acumuladas na posição
- Garante que o compound funcione corretamente

## ⚠️ Observações Importantes

1. **CompoundHelper precisa ser deployado uma vez por pool**
   - O script verifica se já existe e reutiliza
   - Se não existir, deploya um novo e configura

2. **Owner do hook**
   - Apenas o owner do hook pode chamar `setCompoundHelper()`
   - O script usa a mesma private key do deploy

3. **Fees reais vs estimadas**
   - Quando o helper está configurado, usa fees reais
   - Quando não está configurado, usa fees estimadas (comportamento anterior)

## 🔍 Verificar Status

Para verificar se o CompoundHelper está configurado:

```solidity
address helper = hook.compoundHelper(poolId);
// Se helper != address(0), está configurado
```

## 📊 Resultado Esperado

Após executar o script, você deve ver:

```
=== Configure and Execute Compound with Real Fees ===
...
=== Deploying New CompoundHelper === (ou Using Existing)
CompoundHelper deployed at: 0x...
=== Configuring CompoundHelper in Hook ===
CompoundHelper configured successfully!
...
=== Preparing Compound ===
Compound prepared successfully!
Fees0 to compound: ...
Fees1 to compound: ...
...
=== Executing Compound via Helper ===
Compound executed successfully!
...
SUCCESS: Fees were reinvested!
```

## 🚀 Próximos Passos

1. Execute o script
2. Verifique os logs para confirmar que funcionou
3. Se houver erros, verifique:
   - Se o hook é owner (mesma private key)
   - Se há fees suficientes para compound
   - Se passaram 4 horas desde o último compound

