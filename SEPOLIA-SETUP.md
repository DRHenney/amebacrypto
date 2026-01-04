# 🌊 Guia de Setup - Sepolia Testnet

## O que é Sepolia?

Sepolia é uma testnet pública do Ethereum usada para testar contratos antes de enviar para mainnet. É gratuita e você pode obter ETH de teste gratuitamente.

---

## 📋 Passo 1: Obter ETH de Teste (Sepolia ETH)

Você precisa de Sepolia ETH para pagar o gas das transações. Aqui estão as principais faucets:

### Opções de Faucets:

1. **Alchemy Sepolia Faucet** (Recomendado)
   - URL: https://sepoliafaucet.com/
   - Requer: Conta Alchemy (grátis)
   - Quantidade: 0.5 ETH por dia

2. **Infura Sepolia Faucet**
   - URL: https://www.infura.io/faucet/sepolia
   - Requer: Conta Infura (grátis)
   - Quantidade: 0.5 ETH por dia

3. **QuickNode Sepolia Faucet**
   - URL: https://faucet.quicknode.com/ethereum/sepolia
   - Requer: Conta QuickNode (grátis)
   - Quantidade: 0.1 ETH por dia

4. **PoW Faucet** (Alternativa)
   - URL: https://sepolia-faucet.pk910.de/
   - Requer: Resolver captcha de mineração (Proof of Work)
   - Quantidade: Variável

### Como Usar:

1. Conecte sua carteira MetaMask (ou outra)
2. Certifique-se de que a rede Sepolia está adicionada
3. Copie o endereço da sua carteira
4. Cole no faucet e solicite ETH
5. Aguarde alguns minutos para receber

**Quantidade recomendada**: Pelo menos 0.5 ETH para testar o hook completo

---

## 🔧 Passo 2: Adicionar Sepolia no MetaMask

Se você usa MetaMask, precisa adicionar a rede Sepolia:

### Configurações da Rede Sepolia:

- **Network Name**: Sepolia
- **RPC URL**: `https://rpc.sepolia.org` ou `https://ethereum-sepolia-rpc.publicnode.com`
- **Chain ID**: `11155111`
- **Currency Symbol**: `ETH`
- **Block Explorer**: `https://sepolia.etherscan.io`

### Como Adicionar:

1. Abra MetaMask
2. Clique no menu de redes (canto superior esquerdo)
3. Clique em "Add Network" ou "Add a network manually"
4. Preencha as informações acima
5. Salve

---

## 🌐 Passo 3: RPC URLs para Sepolia

Você pode usar RPC públicos ou criar uma conta gratuita:

### RPC Públicos (Gratuitos):

```bash
# RPC Público 1
https://rpc.sepolia.org

# RPC Público 2
https://ethereum-sepolia-rpc.publicnode.com

# RPC Público 3
https://sepolia.gateway.tenderly.co
```

### RPC com API Key (Mais confiável):

**Alchemy:**
1. Crie conta em https://www.alchemy.com/
2. Crie um novo app selecionando "Sepolia"
3. Copie a RPC URL: `https://eth-sepolia.g.alchemy.com/v2/SEU_API_KEY`

**Infura:**
1. Crie conta em https://www.infura.io/
2. Crie um novo projeto
3. Selecione "Sepolia"
4. Copie a RPC URL: `https://sepolia.infura.io/v3/SEU_API_KEY`

---

## 📦 Passo 4: Endereços Importantes na Sepolia

### Tokens de Teste:

**USDC Sepolia:**
- Endereço: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- Decimais: 6
- Para obter: Use faucets ou swap ETH por USDC

**WETH Sepolia:**
- Endereço: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`
- Decimais: 18
- Wrap ETH diretamente no contrato WETH

**ETH:**
- ETH nativo (use direto)

### Explorador de Blocos:

- **Etherscan Sepolia**: https://sepolia.etherscan.io/

---

## 🏊 Passo 5: PoolManager do Uniswap v4

**Importante**: O Uniswap v4 ainda não está oficialmente deployado em Sepolia. Você tem duas opções:

### Opção 1: Fazer Deploy do PoolManager (Recomendado para testes)

Você pode fazer deploy do PoolManager você mesmo usando nosso script:

```bash
forge script script/testing/00_DeployV4.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Opção 2: Usar PoolManager já deployado (se existir)

Verifique se há um PoolManager oficial do Uniswap v4 deployado na Sepolia. Se houver, use o endereço oficial.

---

## ✅ Checklist Rápido

Antes de começar o deploy:

- [ ] ✅ Carteira criada/configurada
- [ ] ✅ Rede Sepolia adicionada no MetaMask
- [ ] ✅ Obteve pelo menos 0.5 Sepolia ETH
- [ ] ✅ Tem RPC URL da Sepolia
- [ ] ✅ Endereço da carteira anotado
- [ ] ✅ Chave privada da carteira (para .env)

---

## 🚨 Dicas Importantes

1. **Nunca compartilhe sua chave privada** com ninguém
2. **Use uma carteira separada** para testes (não use sua carteira principal)
3. **ETH de testnet não tem valor real** - é apenas para testes
4. **Gas fees são muito baixas** na testnet (quase gratuitas)
5. **Aguarde confirmações** antes de assumir que a transação foi bem-sucedida

---

## 🔗 Links Úteis

- **Etherscan Sepolia**: https://sepolia.etherscan.io/
- **Alchemy Faucet**: https://sepoliafaucet.com/
- **Infura Faucet**: https://www.infura.io/faucet/sepolia
- **Metamask**: https://metamask.io/

---

Agora você está pronto para configurar o `.env` e começar o deploy! 🚀



