# 🚀 Guia Completo de Deploy e Configuração - AutoCompoundHook

Este guia te ajudará a fazer o deploy do seu hook na Uniswap v4 testnet e configurá-lo corretamente.

## 📋 Pré-requisitos

1. ✅ Projeto compilado sem erros (`forge build`)
2. ✅ Todos os testes passando (`forge test`)
3. ✅ Carteira com ETH para gas (testnet)
4. ✅ Variáveis de ambiente configuradas (`.env`)

---

## 🔧 Passo 1: Configurar Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```bash
# Chave privada da carteira (SEM 0x no início)
PRIVATE_KEY=sua_chave_privada_aqui

# Endereço do PoolManager do Uniswap v4 na testnet
# Sepolia Testnet: (verificar endereço oficial)
POOL_MANAGER=0xE03A1074c86CFeDd5C142C4F04F1a1536e203543

# RPC URL da testnet
SEPOLIA_RPC_URL=https://rpc.sepolia.org
# Ou usar Infura/Alchemy:
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/SEU_API_KEY
```

⚠️ **IMPORTANTE**: Nunca commite o arquivo `.env` no git! Adicione ao `.gitignore`.

---

## 📦 Passo 2: Verificar PoolManager na Testnet

O Uniswap v4 pode estar em diferentes testnets. Verifique o endereço correto do PoolManager:

- **Sepolia**: Verificar na documentação oficial do Uniswap v4
- **Unichain Sepolia**: Pode ter um endereço diferente

Você pode precisar fazer deploy do PoolManager se ainda não existir:

```bash
# Deploy do PoolManager (se necessário)
forge script script/testing/00_DeployV4.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

---

## 🎯 Passo 3: Deploy do Hook

Execute o script de deploy:

```bash
# Compilar primeiro
forge build

# Deploy na Sepolia
forge script script/DeployAutoCompoundHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**O que acontece:**

1. O script minera um endereço válido para o hook (com flags corretos)
2. Faz deploy usando CREATE2
3. Salva as informações do deploy

**Salve estas informações:**
- ✅ Endereço do Hook deployado
- ✅ Salt usado no deploy
- ✅ Endereço do Owner (sua carteira)

---

## ⚙️ Passo 4: Configurar o Hook Após Deploy

Após o deploy, você precisa configurar o hook. Crie um script ou execute via cast/forge:

### 4.1. Habilitar a Pool

```bash
# Via cast (substitua os valores)
cast send <HOOK_ADDRESS> \
  "setPoolConfig((address,address,uint24,int24,address),bool)" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  true \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 4.2. Configurar Preços dos Tokens (USD)

```bash
# Exemplo: ETH = $3000, USDC = $1
# Preços devem estar em formato 18 decimais (3000e18 para ETH)

cast send <HOOK_ADDRESS> \
  "setTokenPricesUSD((address,address,uint24,int24,address),uint256,uint256)" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  3000000000000000000000 \
  1000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 4.3. Configurar Tick Range

```bash
# Configurar o range onde a liquidez será adicionada no compound
# Exemplo: full range (-887272 a 887272)

cast send <HOOK_ADDRESS> \
  "setPoolTickRange((address,address,uint24,int24,address),int24,int24)" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  -887272 \
  887272 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 4.4. Configurar Pool Intermediária (se necessário)

Se a pool principal não contém USDC, configure uma pool intermediária:

```bash
cast send <HOOK_ADDRESS> \
  "setIntermediatePool(address,(address,address,uint24,int24,address))" \
  <TOKEN_ADDRESS> \
  "(<TOKEN>,<USDC>,3000,60,0x0000000000000000000000000000000000000000)" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## 🏊 Passo 5: Criar Pool com o Hook

Você precisa criar uma pool no Uniswap v4 usando seu hook. Use um script ou interface:

```bash
forge script script/01_CreatePoolAndAddLiquidity.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

**Configurações da Pool:**
- `currency0`: Token0 (endereço menor)
- `currency1`: Token1 (endereço maior)
- `fee`: 3000 (0.3%)
- `tickSpacing`: 60
- `hooks`: Endereço do seu hook

---

## ✅ Passo 6: Verificar Configuração

Verifique se tudo está configurado corretamente:

```bash
# Ver informações da pool
cast call <HOOK_ADDRESS> \
  "getPoolInfo((address,address,uint24,int24,address))" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  --rpc-url $SEPOLIA_RPC_URL

# Verificar se pode executar compound
cast call <HOOK_ADDRESS> \
  "canExecuteCompound((address,address,uint24,int24,address))" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 🤖 Passo 7: Configurar Keeper (Opcional mas Recomendado)

Para executar o compound automaticamente a cada 4 horas, configure um keeper:

### Opções de Keeper:

1. **Gelato Network**: 
   - Criar uma task automática
   - Chamar `checkAndCompound()` periodicamente

2. **OpenZeppelin Defender**:
   - Criar um autotask
   - Executar a cada 4 horas

3. **Script próprio**:
   - Rodar via cron job
   - Verificar `canExecuteCompound()` antes de executar

### Exemplo de Script Keeper:

```solidity
// keeper.js ou keeper.ts
const hookAddress = "0x...";
const poolKey = {
  currency0: "...",
  currency1: "...",
  fee: 3000,
  tickSpacing: 60,
  hooks: hookAddress
};

async function checkAndCompound() {
  // Verificar se pode executar
  const canExecute = await hook.canExecuteCompound(poolKey);
  
  if (canExecute.canCompound) {
    // Executar compound
    await hook.checkAndCompound(poolKey);
    console.log("Compound executado com sucesso!");
  } else {
    console.log("Não pode executar:", canExecute.reason);
  }
}

// Executar a cada 4 horas
setInterval(checkAndCompound, 4 * 60 * 60 * 1000);
```

---

## 🧪 Passo 8: Testar o Hook

### 8.1. Fazer Swaps na Pool

```bash
forge script script/03_Swap.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

### 8.2. Verificar Acumulação de Fees

```bash
# Ver fees acumuladas
cast call <HOOK_ADDRESS> \
  "getAccumulatedFees((address,address,uint24,int24,address))" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  --rpc-url $SEPOLIA_RPC_URL
```

### 8.3. Executar Compound Manualmente (Teste)

```bash
# Avançar tempo no fork local ou esperar 4 horas na testnet
cast send <HOOK_ADDRESS> \
  "checkAndCompound((address,address,uint24,int24,address))" \
  "(<TOKEN0>,<TOKEN1>,3000,60,<HOOK_ADDRESS>)" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## 📊 Passo 9: Monitoramento

Monitore o hook regularmente:

### Métricas importantes:

1. **Fees acumuladas**: `getAccumulatedFees()`
2. **Status do compound**: `canExecuteCompound()`
3. **Eventos emitidos**: `FeesCompounded`
4. **Balance do FEE_RECIPIENT**: Verificar saldo de USDC

### Ferramentas úteis:

- **Etherscan** (Sepolia): Ver transações e eventos
- **Tenderly**: Simular e debugar transações
- **OpenZeppelin Defender**: Monitorar contratos

---

## 🔐 Passo 10: Segurança

### Checklist de Segurança:

- [ ] ✅ Owner configurado corretamente
- [ ] ✅ Private key seguro (não compartilhar)
- [ ] ✅ Verificar todas as configurações antes de produção
- [ ] ✅ Testar em testnet extensivamente
- [ ] ✅ Considerar auditoria antes de mainnet
- [ ] ✅ Verificar endereço do FEE_RECIPIENT

---

## 🚨 Troubleshooting

### Problema: Hook não acumula fees

**Solução**: 
- Verificar se `setPoolConfig(key, true)` foi chamado
- Verificar se a pool foi inicializada com o hook correto

### Problema: Compound não executa

**Solução**:
- Verificar se passaram 4 horas desde último compound
- Verificar se fees >= 20x custo de gas
- Usar `canExecuteCompound()` para ver motivo

### Problema: Erro no deploy

**Solução**:
- Verificar se PoolManager existe na rede
- Verificar se tem ETH suficiente para gas
- Verificar flags do hook estão corretos

---

## 📝 Próximos Passos

1. ✅ Testar extensivamente em testnet
2. ✅ Monitorar por alguns dias
3. ✅ Considerar auditoria de segurança
4. ✅ Preparar para mainnet (quando Uniswap v4 for lançado)

---

## 📚 Recursos Adicionais

- [Uniswap v4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [v4-by-example](https://v4-by-example.org)
- [Hook Development Guide](https://docs.uniswap.org/contracts/v4/concepts/protocol/hooks)

---

## 🎉 Sucesso!

Se você chegou até aqui, seu hook está deployado e funcionando! 

Mantenha monitoramento ativo e esteja preparado para ajustes conforme necessário.



