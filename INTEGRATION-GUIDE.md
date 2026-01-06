# 🔌 Guia de Integração - AutoCompoundHook

**Versão**: 1.0  
**Última atualização**: 2025-01-05

---

## 📋 **Índice**

- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Configuração Inicial](#configuração-inicial)
- [Exemplos de Integração](#exemplos-de-integração)
- [Boas Práticas](#boas-práticas)
- [Checklist de Deploy](#checklist-de-deploy)

---

## 🔧 **Pré-requisitos**

### **Técnicos**
- ✅ Foundry instalado ([guia de instalação](https://book.getfoundry.sh/getting-started/installation))
- ✅ Node.js (opcional, para scripts auxiliares)
- ✅ Carteira com ETH para deploy e transações
- ✅ Acesso a RPC endpoint (Sepolia, Mainnet, etc.)

### **Conhecimento**
- ✅ Conhecimento básico de Solidity
- ✅ Familiaridade com Uniswap V4
- ✅ Entendimento de hooks e callbacks

---

## 📦 **Instalação**

### **1. Clone o Repositório**

```bash
git clone https://github.com/DRHenney/amebacrypto.git
cd amebacrypto
```

### **2. Instale Dependências**

```bash
forge install
```

### **3. Compile**

```bash
forge build --via-ir
```

### **4. Execute Testes**

```bash
forge test --via-ir -vvv
```

---

## ⚙️ **Configuração Inicial**

### **1. Configure Variáveis de Ambiente**

Crie um arquivo `.env` na raiz do projeto:

```bash
# Chave privada para deploy e transações
PRIVATE_KEY=sua_chave_privada_aqui

# Endereço do PoolManager (Uniswap V4)
POOL_MANAGER=0x...

# Endereço do Hook (após deploy)
HOOK_ADDRESS=0x...

# Endereços dos tokens
TOKEN0_ADDRESS=0x...  # Ex: USDC
TOKEN1_ADDRESS=0x...  # Ex: WETH

# RPC URL
SEPOLIA_RPC_URL=https://rpc.sepolia.org
# ou
MAINNET_RPC_URL=https://eth.llamarpc.com
```

### **2. Deploy do Hook**

```bash
# Deploy usando script
bash deploy-hook.sh

# Ou manualmente
forge script script/DeployAutoCompoundHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### **3. Configure o Hook**

Após deploy, configure o hook:

```solidity
// 1. Habilitar pool
hook.setPoolConfig(poolKey, true);

// 2. Configurar preços dos tokens
hook.setTokenPricesUSD(poolKey, 3000e18, 1e18); // ETH = $3000, USDC = $1

// 3. Configurar tick range
int24 tickLower = TickMath.minUsableTick(60);
int24 tickUpper = TickMath.maxUsableTick(60);
hook.setPoolTickRange(poolKey, tickLower, tickUpper);
```

---

## 💻 **Exemplos de Integração**

### **Exemplo 1: Integração Básica**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AutoCompoundHook} from "./src/hooks/AutoCompoundHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract MyIntegration {
    AutoCompoundHook public hook;
    IPoolManager public poolManager;
    
    constructor(address _hook, address _poolManager) {
        hook = AutoCompoundHook(_hook);
        poolManager = IPoolManager(_poolManager);
    }
    
    function setupPool(PoolKey memory poolKey) external {
        // Habilitar pool
        hook.setPoolConfig(poolKey, true);
        
        // Configurar preços
        hook.setTokenPricesUSD(poolKey, 3000e18, 1e18);
        
        // Configurar tick range
        hook.setPoolTickRange(poolKey, -887220, 887220);
    }
    
    function checkFees(PoolKey memory poolKey) external view returns (uint256 fees0, uint256 fees1) {
        return hook.getAccumulatedFees(poolKey);
    }
}
```

### **Exemplo 2: Integração com Keeper**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AutoCompoundHook} from "./src/hooks/AutoCompoundHook.sol";
import {CompoundHelper} from "./src/helpers/CompoundHelper.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

contract MyKeeper {
    AutoCompoundHook public hook;
    IPoolManager public poolManager;
    
    constructor(address _hook, address _poolManager) {
        hook = AutoCompoundHook(_hook);
        poolManager = IPoolManager(_poolManager);
    }
    
    function executeCompoundIfReady(PoolKey memory poolKey) external {
        // 1. Verificar se pode executar
        (bool canCompound, string memory reason,, uint256 feesUSD, uint256 gasUSD) = 
            hook.canExecuteCompound(poolKey);
        
        if (!canCompound) {
            // Log motivo
            emit CompoundNotReady(reason, feesUSD, gasUSD);
            return;
        }
        
        // 2. Preparar compound
        (bool canPrepare, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
            hook.prepareCompound(poolKey);
        
        if (!canPrepare) {
            emit CompoundPrepareFailed();
            return;
        }
        
        // 3. Executar compound
        CompoundHelper helper = new CompoundHelper(poolManager, hook);
        helper.executeCompound(poolKey, params, fees0, fees1);
        
        emit CompoundExecuted(fees0, fees1);
    }
    
    event CompoundNotReady(string reason, uint256 feesUSD, uint256 gasUSD);
    event CompoundPrepareFailed();
    event CompoundExecuted(uint256 fees0, uint256 fees1);
}
```

### **Exemplo 3: Integração com Múltiplas Pools**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AutoCompoundHook} from "./src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract MultiPoolManager {
    AutoCompoundHook public hook;
    PoolKey[] public pools;
    
    constructor(address _hook) {
        hook = AutoCompoundHook(_hook);
    }
    
    function addPool(PoolKey memory poolKey) external {
        pools.push(poolKey);
        
        // Configurar pool
        hook.setPoolConfig(poolKey, true);
        hook.setTokenPricesUSD(poolKey, 3000e18, 1e18);
        hook.setPoolTickRange(poolKey, -887220, 887220);
    }
    
    function checkAllPools() external view returns (uint256 totalFees0, uint256 totalFees1) {
        for (uint i = 0; i < pools.length; i++) {
            (uint256 fees0, uint256 fees1) = hook.getAccumulatedFees(pools[i]);
            totalFees0 += fees0;
            totalFees1 += fees1;
        }
    }
    
    function compoundAllReadyPools() external {
        for (uint i = 0; i < pools.length; i++) {
            (bool canCompound,,,) = hook.canExecuteCompound(pools[i]);
            if (canCompound) {
                // Executar compound para esta pool
                // (implementar lógica de compound)
            }
        }
    }
}
```

---

## ✅ **Boas Práticas**

### **1. Configuração**

- ✅ **Sempre configure preços** antes de usar o hook
- ✅ **Configure tick range** antes de adicionar liquidez
- ✅ **Use full range** para máxima compatibilidade
- ✅ **Verifique configuração** antes de executar compound

### **2. Segurança**

- ✅ **Nunca exponha private key** em código
- ✅ **Use variáveis de ambiente** para dados sensíveis
- ✅ **Verifique endereços** antes de interagir
- ✅ **Teste em testnet** antes de mainnet

### **3. Gas Optimization**

- ✅ **Verifique condições** antes de executar compound
- ✅ **Use `canExecuteCompound`** para evitar transações desnecessárias
- ✅ **Monitore custo de gas** vs valor das fees
- ✅ **Configure keeper** para executar apenas quando necessário

### **4. Monitoramento**

- ✅ **Monitore fees acumuladas** regularmente
- ✅ **Verifique logs** do keeper
- ✅ **Acompanhe eventos** (`FeesCompounded`)
- ✅ **Monitore estado** das pools

---

## 📋 **Checklist de Deploy**

### **Antes do Deploy**

- [ ] Foundry instalado e funcionando
- [ ] Dependências instaladas (`forge install`)
- [ ] Testes passando (`forge test`)
- [ ] Variáveis de ambiente configuradas (`.env`)
- [ ] Carteira com ETH suficiente

### **Deploy**

- [ ] Hook deployado
- [ ] Hook verificado (se usando `--verify`)
- [ ] Endereço do hook salvo no `.env`
- [ ] Pool criada com hook
- [ ] Pool inicializada

### **Configuração**

- [ ] Pool habilitada (`setPoolConfig`)
- [ ] Preços configurados (`setTokenPricesUSD`)
- [ ] Tick range configurado (`setPoolTickRange`)
- [ ] Liquidez adicionada

### **Verificação**

- [ ] Fees acumulando durante swaps
- [ ] `canExecuteCompound` retornando valores corretos
- [ ] `prepareCompound` funcionando
- [ ] Compound executando com sucesso

### **Automação**

- [ ] Keeper configurado
- [ ] Cron job ou systemd timer ativo
- [ ] Logs sendo salvos
- [ ] Monitoramento configurado

---

## 🔍 **Troubleshooting Comum**

### **Problema: Fees não acumulam**

**Possíveis causas:**
- Pool não está habilitada
- Hook não está configurado corretamente
- Swaps não estão passando pelo hook

**Solução:**
```solidity
// Verificar se pool está habilitada
(, uint256 fees0, uint256 fees1,,) = hook.getPoolInfo(poolKey);
// Se fees0 e fees1 são 0, verificar configuração
```

### **Problema: Compound não executa**

**Possíveis causas:**
- Condições não atendidas (4 horas, 20x gas cost)
- Tick range não configurado
- Preços não configurados

**Solução:**
```solidity
// Verificar condições
(bool canCompound, string memory reason,,,) = hook.canExecuteCompound(poolKey);
// Ver reason para identificar problema
```

### **Problema: Erro "Invalid tick range"**

**Possíveis causas:**
- `tickLower >= tickUpper`
- Ticks não alinhados com `tickSpacing`

**Solução:**
```solidity
// Usar funções helper do TickMath
int24 tickLower = TickMath.minUsableTick(tickSpacing);
int24 tickUpper = TickMath.maxUsableTick(tickSpacing);
```

---

## 📚 **Recursos Adicionais**

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Arquitetura detalhada
- [API-REFERENCE.md](./API-REFERENCE.md) - Referência completa da API
- [HOOK-AUTO-COMPOUND.md](./HOOK-AUTO-COMPOUND.md) - Documentação do hook
- [README-KEEPER.md](./README-KEEPER.md) - Guia do keeper
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Guia de troubleshooting

---

**Última atualização**: 2025-01-05

