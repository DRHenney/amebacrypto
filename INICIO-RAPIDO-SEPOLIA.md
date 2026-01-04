# 🚀 Início Rápido - Deploy na Sepolia

Este guia rápido te levará do zero ao deploy do hook em poucos passos.

---

## ⚡ Passo 1: Preparar Carteira (5 minutos)

### 1.1. Instalar MetaMask (se não tiver)
- Baixe em: https://metamask.io/
- Crie uma nova carteira OU use uma existente

### 1.2. Adicionar Rede Sepolia
1. Abra MetaMask
2. Clique no menu de redes (canto superior)
3. Clique em "Add Network" → "Add a network manually"
4. Preencha:
   - **Network Name**: Sepolia
   - **RPC URL**: `https://rpc.sepolia.org`
   - **Chain ID**: `11155111`
   - **Currency Symbol**: `ETH`
   - **Block Explorer**: `https://sepolia.etherscan.io`
5. Salve

### 1.3. Obter Sepolia ETH (Gratuito!)
1. Acesse: https://sepoliafaucet.com/
2. Conecte com MetaMask ou Google
3. Cole o endereço da sua carteira
4. Solicite ETH
5. Aguarde alguns minutos

**Você precisa de pelo menos 0.5 ETH para testar tudo.**

---

## ⚡ Passo 2: Configurar Projeto (2 minutos)

### 2.1. Criar arquivo `.env`

**No Windows PowerShell:**
```powershell
# Copiar e editar manualmente, ou execute:
wsl bash setup-sepolia.sh
```

**Ou crie manualmente:**

Crie um arquivo chamado `.env` na raiz do projeto com:

```bash
# Sua chave privada (sem 0x)
PRIVATE_KEY=sua_chave_privada_aqui

# RPC URL (use uma das opções)
SEPOLIA_RPC_URL=https://rpc.sepolia.org
# Ou: https://eth-sepolia.g.alchemy.com/v2/SEU_API_KEY
# Ou: https://sepolia.infura.io/v3/SEU_API_KEY

# Deixar vazio por enquanto (será preenchido após deploy)
POOL_MANAGER=

# Deixar vazio por enquanto
HOOK_ADDRESS=

# Tokens na Sepolia
TOKEN0_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
TOKEN1_ADDRESS=0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14

# Preços em USD (formato: price * 1e18)
TOKEN0_PRICE_USD=1000000000000000000
TOKEN1_PRICE_USD=3000000000000000000000

# Tick range
TICK_LOWER=-887272
TICK_UPPER=887272
```

⚠️ **IMPORTANTE**: 
- NUNCA compartilhe sua chave privada
- NUNCA commite o arquivo `.env`

### 2.2. Obter sua Chave Privada
1. Abra MetaMask
2. Clique nos três pontos (menu)
3. Clique em "Account details"
4. Clique em "Export Private Key"
5. Digite sua senha
6. **Copie SEM o `0x` no início**

---

## ⚡ Passo 3: Deploy do PoolManager (5 minutos)

Como o Uniswap v4 ainda não está oficialmente na Sepolia, você precisa fazer deploy do PoolManager:

```bash
# No WSL ou terminal Linux
forge script script/DeployPoolManagerSepolia.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**Após o deploy:**
1. Copie o endereço do PoolManager mostrado no output
2. Edite o arquivo `.env`
3. Adicione: `POOL_MANAGER=0x...` (com o endereço)

---

## ⚡ Passo 4: Deploy do Hook (5 minutos)

```bash
forge script script/DeployAutoCompoundHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**Após o deploy:**
1. Copie o endereço do Hook mostrado no output
2. Edite o arquivo `.env`
3. Adicione: `HOOK_ADDRESS=0x...` (com o endereço)

---

## ⚡ Passo 5: Configurar o Hook (2 minutos)

```bash
forge script script/ConfigureHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

Este script vai:
- ✅ Habilitar a pool
- ✅ Configurar preços dos tokens
- ✅ Configurar tick range
- ✅ Verificar se está tudo OK

---

## ⚡ Passo 6: Criar Pool (Opcional)

Se você quiser criar uma pool de teste:

```bash
forge script script/01_CreatePoolAndAddLiquidity.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

---

## ✅ Verificar Tudo Funcionou

### Verificar no Etherscan:
1. Acesse: https://sepolia.etherscan.io/
2. Cole o endereço do seu Hook
3. Verifique as transações

### Verificar configuração via cast:
```bash
cast call <HOOK_ADDRESS> \
  "getPoolInfo((address,address,uint24,int24,address))" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 🆘 Problemas Comuns

### Erro: "insufficient funds"
- Você não tem ETH suficiente
- Obtenha mais em: https://sepoliafaucet.com/

### Erro: "nonce too low"
- Aguarde alguns segundos e tente novamente

### Erro: "PoolManager not found"
- Certifique-se de ter feito deploy do PoolManager primeiro
- Verifique se o endereço está correto no `.env`

### RPC muito lento
- Use uma RPC com API key (Alchemy ou Infura)
- São gratuitas e muito mais rápidas

---

## 📚 Documentação Completa

- **Guia Detalhado**: Veja `GUIA-DEPLOY-TESTNET.md`
- **Setup Sepolia**: Veja `SEPOLIA-SETUP.md`
- **Checklist**: Veja `CHECKLIST-DEPLOY.md`

---

## 🎉 Pronto!

Se você chegou até aqui, seu hook está deployado na Sepolia! 

**Próximos passos:**
1. Testar com swaps reais
2. Monitorar acumulação de fees
3. Configurar keeper para automação



