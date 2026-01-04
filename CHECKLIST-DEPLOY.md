# ✅ Checklist de Deploy - AutoCompoundHook

Use este checklist para garantir que está tudo pronto antes do deploy.

## 📋 Antes de Começar

### 1. Verificações Técnicas
- [x] ✅ Projeto compila sem erros (`forge build`)
- [x] ✅ Todos os testes passam (`forge test`)
- [x] ✅ FEE_RECIPIENT atualizado para: `0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c`
- [ ] ⏳ Carteira com ETH suficiente (testnet)
- [ ] ⏳ Arquivo `.env` criado e configurado

### 2. Informações Necessárias

Você precisa ter estas informações prontas:

#### Carteira
- [ ] ⏳ Chave privada da carteira (sem `0x`)
- [ ] ⏳ Endereço da carteira
- [ ] ⏳ Saldo de ETH na testnet (Sepolia)

#### Uniswap v4
- [ ] ⏳ Endereço do PoolManager na testnet
  - **Sepolia**: Verificar endereço oficial
  - **Ou**: Fazer deploy do PoolManager você mesmo

#### Pool que você quer usar
- [ ] ⏳ Endereço do Token0 (ex: USDC)
- [ ] ⏳ Endereço do Token1 (ex: WETH)
- [ ] ⏳ Preço atual do Token0 em USD
- [ ] ⏳ Preço atual do Token1 em USD

#### RPC
- [ ] ⏳ RPC URL da testnet
  - Sepolia: `https://rpc.sepolia.org`
  - Ou Infura/Alchemy: `https://sepolia.infura.io/v3/SEU_API_KEY`

---

## 🚀 Passo a Passo do Deploy

### Passo 1: Criar arquivo `.env`

```bash
# Na raiz do projeto, criar arquivo .env
# (ou eu posso te ajudar a criar)
```

### Passo 2: Deploy do Hook

```bash
forge script script/DeployAutoCompoundHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Passo 3: Configurar o Hook

```bash
forge script script/ConfigureHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

### Passo 4: Criar Pool

```bash
forge script script/01_CreatePoolAndAddLiquidity.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

---

## 📝 Notas Importantes

1. **Segurança**: Nunca commite o arquivo `.env`!
2. **Testnet primeiro**: Sempre teste em testnet antes de mainnet
3. **Gas**: Mantenha ETH suficiente para todas as transações
4. **Backup**: Salve todos os endereços deployados

---

## 🔍 Informações a Salvar Após Deploy

Após cada passo, salve estas informações:

### Após Deploy do Hook:
- [ ] Endereço do Hook: `0x...`
- [ ] Salt usado: `0x...`
- [ ] Owner: `0x...`

### Após Configuração:
- [ ] Pool Key configurada
- [ ] Preços dos tokens configurados
- [ ] Tick range configurado

### Após Criar Pool:
- [ ] Pool ID
- [ ] Liquidez inicial adicionada



