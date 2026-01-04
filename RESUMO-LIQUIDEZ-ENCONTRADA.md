# 📊 Resumo: Liquidez Encontrada em Pools Antigas

**Data**: 2025-01-27

---

## ✅ Pools com Liquidez Encontradas

Foram encontradas **3 pools** com liquidez de 1,000,000 cada:

### 1. Pool com Hook: `0xEaF32b3657427a3796928035d6B2DBb28C355540`
- **Pool ID**: `19497211606869385185446633499189000947740126804924914527979230758992169259194`
- **Status**: Pool inicializada
- **Liquidez**: 1,000,000
- **Current Tick**: 414425
- **Observação**: Hook mais recente (DEPLOY-HOOK-ATUALIZADO-COMPLETO.md)

### 2. Pool com Hook: `0x01308892b21f3E6fB6fF8e13a29D775e991D5540`
- **Pool ID**: `28256298611757681241013306313511050759847663993524451406477851312375608566082`
- **Status**: Pool inicializada
- **Liquidez**: 1,000,000
- **Current Tick**: 456016
- **Observação**: Hook médio (INFORMACOES-HOOK-DEPLOY.md)

### 3. Pool com Hook: `0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540`
- **Pool ID**: `124155924556843589663578157422828627100435937124527691921033459863398328909`
- **Status**: Pool inicializada
- **Liquidez**: 1,000,000
- **Current Tick**: 46219
- **Observação**: Hook mais antigo (SITUACAO-COMPOUND.md)

---

## 🔍 Pool Atual (no .env)

- **Hook Address**: `0x5D2221e062d9577Ceec30661A6803a5A67D6D540`
- **Pool ID**: `108702570663019306683919409932166652631825429314170560774432662186877439904016`
- **Status**: Pool inicializada
- **Liquidez**: 0 (sem liquidez)

---

## 📝 Próximos Passos

Para obter 0.03 WETH, você pode:

1. **Remover liquidez de uma das pools antigas** (recomendado: hook mais antigo `0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540`)
2. **Fazer unwrap do WETH recebido** para obter ETH

### Comandos disponíveis:

```bash
# Para remover liquidez de pool antiga (hook mais antigo por padrão)
bash remover-liquidez-pool-antiga.sh

# Para usar outro hook, defina a variável:
export OLD_HOOK_ADDRESS=0xEaF32b3657427a3796928035d6B2DBb28C355540
bash remover-liquidez-pool-antiga.sh

# Para fazer unwrap do WETH para ETH (após receber WETH)
bash unwrap-weth-para-eth.sh
```

---

## ⚠️ Nota Técnica

O script de remoção de liquidez encontrou um erro `SafeCastOverflow()` ao tentar remover 60% da liquidez. Isso pode ser resolvido:

1. Removendo toda a liquidez de uma vez (como no script `remover-toda-liquidez.sh`)
2. Ajustando a quantidade de liquidez a remover
3. Usando uma pool diferente

