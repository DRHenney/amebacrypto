# 🔍 Guia de Verificação de Estado

Este guia explica como verificar o estado atual do hook deployado na Sepolia.

---

## 📋 O que é Verificado

O script `VerifyHookState.s.sol` verifica:

1. **Informações Básicas**
   - Endereços do PoolManager e Hook
   - Pool ID
   - Owner do hook

2. **Configuração da Pool**
   - Se a pool está habilitada
   - Tick range configurado

3. **Fees Acumuladas**
   - Quantidade de fees0 acumuladas
   - Quantidade de fees1 acumuladas

4. **Saldos do Hook**
   - Saldo de token0 no hook
   - Saldo de token1 no hook

5. **Estado da Pool**
   - Preço atual (sqrtPriceX96)
   - Tick atual
   - Liquidez total

6. **Status do Compound**
   - Se pode executar compound
   - Motivo (se não pode)
   - Tempo até próximo compound
   - Valor das fees em USD
   - Custo de gas estimado

7. **Último Compound**
   - Timestamp do último compound
   - Tempo desde o último compound

---

## 🚀 Como Usar

### Opção 1: Script Bash (Recomendado)

```bash
# Dar permissão de execução (primeira vez)
chmod +x verificar-estado-hook.sh

# Executar
./verificar-estado-hook.sh
```

### Opção 2: Forge Script Direto

```bash
forge script script/VerifyHookState.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  -vvv
```

---

## 📊 Interpretando os Resultados

### Se `Can Execute Compound: true`
- ✅ Todas as condições foram atendidas
- ✅ Pode executar compound agora
- ✅ Fees são >= 20x o custo de gas
- ✅ Passaram 4 horas desde último compound (ou nunca executou)

**Próximo passo**: Executar compound usando `TestCompound.s.sol`

### Se `Can Execute Compound: false`

Verifique o `Reason`:

- **"Pool not enabled"**
  - Pool não está habilitada
  - Execute `ConfigureHook.s.sol`

- **"No accumulated fees"**
  - Não há fees acumuladas ainda
  - Execute mais swaps para acumular fees

- **"4 hours not elapsed"**
  - Ainda não passaram 4 horas desde último compound
  - Aguarde o tempo indicado em `Time Until Next Compound`

- **"Fees less than 20x gas cost"**
  - Fees acumuladas são insuficientes
  - Execute mais swaps ou aguarde mais fees acumularem

- **"Token prices not configured"**
  - Preços dos tokens não foram configurados
  - Execute `ConfigureHook.s.sol` para configurar preços

---

## 🔄 Comandos Úteis Adicionais

### Verificar apenas fees acumuladas

```bash
cast call $HOOK_ADDRESS \
  "getAccumulatedFees((address,address,uint24,int24,address))" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url $SEPOLIA_RPC_URL
```

### Verificar se pool está habilitada

```bash
cast call $HOOK_ADDRESS \
  "poolConfigs(bytes32)((bool))" \
  "<POOL_ID>" \
  --rpc-url $SEPOLIA_RPC_URL
```

### Verificar owner

```bash
cast call $HOOK_ADDRESS \
  "owner()(address)" \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 📝 Exemplo de Saída

```
========================================
  VERIFICAÇÃO DO ESTADO DO HOOK
========================================

=== Informações Básicas ===
PoolManager: 0xc77aE1faE9BB15fDD1Ea96897A12Ec074FA65250
Hook: 0x7bc9ddcbe9f25a249ac4c07a6d86616e78e45540
Pool ID: 0x...
Owner: 0x63f976191f9Dd75bd5b0fD81320D37FBC0d74080

=== Configuração da Pool ===
Pool Enabled: true
Tick Lower: -887272
Tick Upper: 887272

=== Fees Acumuladas ===
Fees0 (Token0): 5000000
Fees1 (Token1): 2000000000000000

=== Status do Compound ===
Can Execute Compound: false
Reason: 4 hours not elapsed
Time Until Next Compound: 7200 seconds
Time Until Next Compound: 2 hours 0 minutes
Fees Value (USD): 5000000000000000000
Gas Cost (USD): 100000000000000000
Fees/Gas Ratio: 50 x
Required Ratio: 20x
Meets Requirement: true

========================================
  RESUMO
========================================
Pool Configurada: SIM
Fees Acumuladas: SIM
Pode Executar Compound: NÃO
Motivo: 4 hours not elapsed
========================================
```

---

## 🆘 Troubleshooting

### Erro: "Hook address not found"
- Verifique se `HOOK_ADDRESS` está correto no `.env`
- Verifique se o hook foi deployado

### Erro: "Pool not initialized"
- A pool pode não ter sido criada ainda
- Execute `CreatePool.s.sol` primeiro

### Valores estranhos nos fees
- Lembre-se que USDC tem 6 decimais
- WETH tem 18 decimais
- Use os valores "formato legível" para entender melhor

---

**Script criado e pronto para uso!** 🎉

