# 📍 Endereços e IDs na Sepolia

**Rede**: Sepolia (Chain ID: 11155111)  
**Data**: 2025-01-27

---

## 🏊 Pool Information

### ⚠️ Importante: Uniswap V4 não usa endereços de contrato para pools

No Uniswap V4, as pools **não têm um endereço de contrato** como no V3. Elas são identificadas por um **Pool ID** (hash do PoolKey).

### Pool ID

**Pool ID**: `28256298611757681241013306313511050759847663993524451406477851312375608566082`

**Como pesquisar:**
- Use o Pool ID acima em exploradores de blockchain
- Pesquise por transações relacionadas ao PoolManager
- Use o PoolManager address + Pool ID para encontrar eventos

---

## 🔗 Endereços Importantes

### PoolManager

**Endereço**: `0xc77aE1faE9BB15fDD1Ea96897A12Ec074FA65250`

**Como pesquisar:**
- Etherscan: https://sepolia.etherscan.io/address/0xc77aE1faE9BB15fDD1Ea96897A12Ec074FA65250
- Este é o contrato central que gerencia todas as pools
- Pesquise eventos/transações aqui para ver atividade da pool

---

### AutoCompoundHook

**Endereço**: `0x01308892b21f3E6fB6fF8e13a29D775e991D5540`

**Como pesquisar:**
- Etherscan: https://sepolia.etherscan.io/address/0x01308892b21f3E6fB6fF8e13a29D775e991D5540
- Aqui você pode ver:
  - Configurações da pool
  - Fees acumuladas
  - Eventos do hook
  - Transações relacionadas

---

## 💰 Tokens

### USDC (Token0)

**Endereço**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

**Etherscan**: https://sepolia.etherscan.io/address/0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

### WETH (Token1)

**Endereço**: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`

**Etherscan**: https://sepolia.etherscan.io/address/0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14

---

## 🎯 FEE_RECIPIENT

**Endereço**: `0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c`

**Etherscan**: https://sepolia.etherscan.io/address/0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c

**Função**: Recebe 10% das fees quando liquidez é removida

---

## 📊 Como Pesquisar a Pool

### Opção 1: Via PoolManager (Recomendado)

1. Acesse: https://sepolia.etherscan.io/address/0xc77aE1faE9BB15fDD1Ea96897A12Ec074FA65250
2. Clique em **"Events"** ou **"Internal Txns"**
3. Procure por eventos relacionados ao Pool ID

### Opção 2: Via Hook

1. Acesse: https://sepolia.etherscan.io/address/0x01308892b21f3E6fB6fF8e13a29D775e991D5540
2. Veja eventos emitidos pelo hook:
   - `FeesCompounded`
   - `PoolConfigUpdated`
   - `TokenPricesUpdated`
   - Outros eventos

### Opção 3: Via Pool Key (Para desenvolvedores)

**Pool Key:**
```
currency0: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 (USDC)
currency1: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 (WETH)
fee: 3000 (0.3%)
tickSpacing: 60
hooks: 0x01308892b21f3E6fB6fF8e13a29D775e991D5540
```

Calcule o Pool ID usando `PoolKey.toId()` ou use o Pool ID diretamente acima.

---

## 🔍 Links Úteis

### Exploradores

- **Etherscan Sepolia**: https://sepolia.etherscan.io/
- **Sepolia Testnet Explorer**: https://sepolia.etherscan.io/

### Pesquisa Rápida

**PoolManager:**
https://sepolia.etherscan.io/address/0xc77aE1faE9BB15fDD1Ea96897A12Ec074FA65250

**Hook:**
https://sepolia.etherscan.io/address/0x01308892b21f3E6fB6fF8e13a29D775e991D5540

**FEE_RECIPIENT:**
https://sepolia.etherscan.io/address/0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c

---

## 📝 Nota Importante

No Uniswap V4, toda a lógica da pool está no **PoolManager**. O hook é apenas um contrato que recebe callbacks quando eventos específicos acontecem na pool.

Para ver atividade da pool, pesquise no **PoolManager** usando o **Pool ID** ou via eventos do **Hook**.


