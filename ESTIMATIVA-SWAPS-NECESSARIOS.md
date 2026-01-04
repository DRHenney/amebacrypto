# 📊 Estimativa de Swaps Necessários

**Data**: 2025-01-27

---

## 🎯 Objetivo

Acumular **0.001 WETH** em fees para testar o compound.

---

## 📈 Cálculo

### Fee Rate:
- **0.3%** = 3000 bps
- Cada swap gera fees = `swap_amount × 0.003`

### Diferentes Cenários:

#### Cenário 1: Swap de 0.001 WETH
- **Fees por swap**: 0.001 × 0.003 = **0.000003 WETH**
- **Swaps necessários**: 0.001 ÷ 0.000003 = **~333 swaps**
- **WETH total necessário**: 333 × 0.001 = **0.333 WETH**

#### Cenário 2: Swap de 0.01 WETH
- **Fees por swap**: 0.01 × 0.003 = **0.00003 WETH**
- **Swaps necessários**: 0.001 ÷ 0.00003 = **~33 swaps**
- **WETH total necessário**: 33 × 0.01 = **0.33 WETH**

#### Cenário 3: Swap de 0.1 WETH
- **Fees por swap**: 0.1 × 0.003 = **0.0003 WETH**
- **Swaps necessários**: 0.001 ÷ 0.0003 = **~3-4 swaps**
- **WETH total necessário**: 4 × 0.1 = **0.4 WETH**

---

## 💡 Recomendação

**Usar swap de 0.001 WETH**:
- ✅ Swaps menores = menos risco
- ✅ Swaps alternados (WETH↔USDC) = mais estável
- ✅ **~333 swaps necessários**
- ⚠️ Requer ~0.333 WETH no total

---

## ⏱️ Tempo Estimado

- **Gas por swap**: ~50k-100k gas
- **333 swaps**: ~16-33M gas total
- **Tempo**: Depende do gas price, mas pode levar vários minutos

---

## 🚀 Script Criado

Criado `acumular-fees-automatico.sh` que:
- ✅ Faz swaps automaticamente
- ✅ Alterna direção (WETH↔USDC)
- ✅ Para quando atingir 0.001 WETH em fees
- ✅ Mostra progresso a cada 50 swaps
- ✅ Tem limite de segurança (400 swaps máx)

---

## 📋 Como Usar

```bash
bash acumular-fees-automatico.sh
```

**OU** executar diretamente:

```bash
forge script script/AccumulateFeesUntilThreshold.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvv
```

---

## ⚠️ Considerações

1. **Gas Costs**: 333 swaps = custo significativo de gas
2. **WETH Balance**: Precisa de ~0.333 WETH disponível
3. **Tempo**: Pode levar vários minutos
4. **Interrupção**: Pode parar a qualquer momento (Ctrl+C)

---

## ✅ Após Acumular Fees

Quando atingir 0.001 WETH em fees:

1. ✅ Verificar status:
   ```bash
   bash verificar-estado-hook.sh
   ```

2. ✅ Testar compound:
   ```bash
   bash executar-compound.sh
   ```

---

**Estimativa: ~333 swaps de 0.001 WETH cada = 0.001 WETH em fees** 🎯


