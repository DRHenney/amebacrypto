# 🔗 Informações do Hook para Deploy na Uniswap

**Data**: 2025-01-27

---

## 🎯 Endereço do Hook para Criar Pool

### Sepolia (Testnet)

**Hook Address**: `0x01308892b21f3E6fB6fF8e13a29D775e991D5540`

**Etherscan**: https://sepolia.etherscan.io/address/0x01308892b21f3E6fB6fF8e13a29D775e991D5540

**⚠️ IMPORTANTE**: Este é o endereço na **Sepolia**. Para mainnet, você precisará fazer um novo deploy e usar o novo endereço.

---

## 📋 Como Usar o Hook na Uniswap

### Ao criar uma pool no Uniswap V4:

1. **No PoolKey**, especifique o hook:
   ```solidity
   PoolKey memory poolKey = PoolKey({
       currency0: token0,
       currency1: token1,
       fee: 3000, // 0.3%
       tickSpacing: 60,
       hooks: IHooks(0x01308892b21f3E6fB6fF8e13a29D775e991D5540) // ⬅️ AQUI!
   });
   ```

2. **A UI do Uniswap** também permite selecionar hooks ao criar pools.

---

## 🚀 Quando For para Mainnet (daqui a 2 semanas)

### ⚠️ IMPORTANTE: Endereço será DIFERENTE!

1. **Você precisará fazer um novo deploy do hook na mainnet**
2. **O endereço será diferente** (será gerado durante o deploy)
3. **Use o novo endereço** ao criar pools na mainnet

### Processo:

1. Deploy do hook na mainnet → obter novo endereço
2. Verificar o contrato no Etherscan
3. Usar o novo endereço ao criar pools
4. Configurar o hook após criar a pool

---

## 📊 Informações Completas do Hook (Sepolia)

### Contrato: AutoCompoundHook

- **Endereço**: `0x01308892b21f3E6fB6fF8e13a29D775e991D5540`
- **Rede**: Sepolia (Chain ID: 11155111)
- **Versão**: Com todas as correções de segurança aplicadas
- **Owner**: Configurado durante deploy

### Configuração Necessária Após Criar Pool:

Após criar a pool, você precisará configurar o hook:

1. **Habilitar pool**: `setPoolConfig(poolKey, true)`
2. **Configurar preços USD**: `setTokenPricesUSD(poolKey, price0, price1)`
3. **Configurar tick range**: `setPoolTickRange(poolKey, tickLower, tickUpper)`

---

## ✅ Checklist para Mainnet

Antes de usar na mainnet:

- [ ] Deploy do hook na mainnet
- [ ] Verificar contrato no Etherscan
- [ ] Obter novo endereço do hook
- [ ] Testar criação de pool com o novo endereço
- [ ] Configurar hook após criar pool
- [ ] Monitorar eventos e funcionamento

---

## 🔍 Resumo Rápido

**Para criar pool e ativar o hook:**

1. Use o **Hook Address** no campo `hooks` do `PoolKey`
2. **Sepolia**: `0x01308892b21f3E6fB6fF8e13a29D775e991D5540`
3. **Mainnet**: (será diferente - fazer deploy primeiro)

---

**📝 Documentação criada para referência futura!**


