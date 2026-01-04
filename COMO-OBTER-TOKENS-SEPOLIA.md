# Como Obter Tokens na Sepolia

Este guia explica como obter USDC e WETH na testnet Sepolia para testar seu hook.

---

## 💰 USDC na Sepolia

### Opção 1: Circle Faucet (Recomendado)
- **URL**: https://faucet.circle.com/
- **Rede**: Selecione "Ethereum Sepolia"
- **Limite**: 1 USDC a cada 2 horas por endereço
- **Como usar**:
  1. Acesse o site
  2. Cole o endereço da sua carteira
  3. Selecione "Ethereum Sepolia"
  4. Clique em "Send 1 USDC"
  5. Aguarde alguns minutos

### Opção 2: Bridge CCTP
Se precisar mais USDC, pode fazer bridge de outras chains usando CCTP:
- Siga: https://developers.circle.com/stablecoin/docs/cctp-testnet-quickstart

---

## ⛽ WETH na Sepolia

### Opção 1: Wrap ETH
Se você tem ETH na Sepolia:
1. Use o contrato WETH: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`
2. Chame a função `deposit()` enviando ETH
3. Você receberá WETH na mesma quantidade

**Via Etherscan:**
- Acesse: https://sepolia.etherscan.io/address/0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14#writeContract
- Conecte sua carteira
- Chame `deposit()` enviando o valor desejado de ETH

### Opção 2: Uniswap (se já tiver tokens)
Se você já tem USDC, pode fazer swap USDC -> WETH na Uniswap.

---

## 💡 Valores Recomendados para Testar

### Mínimo para Funcionar:
- **USDC**: 1 USDC (1.000.000 = 1e6) - obtém no Circle Faucet
- **WETH**: 0.01 WETH (10.000.000.000.000.000 = 0.01e18) - wrap 0.01 ETH

### Valores no `.env`:
```bash
LIQUIDITY_TOKEN0_AMOUNT=1000000   # 1 USDC
LIQUIDITY_TOKEN1_AMOUNT=10000000000000000  # 0.01 WETH
```

### Para Swaps:
```bash
SWAP_AMOUNT=100000  # 0.1 USDC (pequeno para testar)
```

---

## 📝 Passos Rápidos

1. **Obter 1 USDC**:
   - https://faucet.circle.com/
   - Rede: Ethereum Sepolia
   - Cole seu endereço
   - Aguarde ~5 minutos

2. **Fazer Wrap de ETH para WETH**:
   - Se você tem 0.1 ETH na Sepolia
   - Wrap 0.01 ETH para WETH (sobra 0.09 ETH para gas)
   - Use Etherscan para chamar `deposit()` no contrato WETH

3. **Ajustar `.env`**:
   ```bash
   LIQUIDITY_TOKEN0_AMOUNT=1000000   # 1 USDC
   LIQUIDITY_TOKEN1_AMOUNT=10000000000000000  # 0.01 WETH
   ```

4. **Executar script**:
   ```bash
   ./executar-scripts-pool.sh
   ```

---

## 🔍 Verificar Saldo

Você pode verificar seus saldos:

**Via Etherscan:**
- https://sepolia.etherscan.io/address/SEU_ENDERECO

**Via MetaMask:**
- Adicione os tokens manualmente se não aparecerem
- USDC: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- WETH: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`

---

## ⚠️ Nota Importante

- O Circle Faucet limita a 1 USDC a cada 2 horas
- Se precisar mais, pode fazer múltiplas requisições ao longo do dia
- Ou usar valores menores para testar primeiro
- Para produção/mainnet, você precisaria comprar os tokens normalmente

---

## 🚀 Próximos Passos Após Obter Tokens

1. Ajuste o `.env` com os valores que você tem
2. Execute `./executar-scripts-pool.sh` opção 2
3. Aguarde a transação confirmar
4. Execute opção 3 para testar swaps e verificar fee accumulation


