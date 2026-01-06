# 🦠 AmebaCrypto - AutoCompound Hook para Uniswap v4

> Hook inteligente que automaticamente reinveste taxas acumuladas de volta na pool de liquidez, maximizando retornos para provedores de liquidez.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-✓-green)](https://book.getfoundry.sh/)
[![Uniswap V4](https://img.shields.io/badge/Uniswap-V4-orange)](https://docs.uniswap.org/contracts/v4/overview)

---

## 📖 **Visão Geral**

O `AutoCompoundHook` é um hook para Uniswap V4 que:

- ✅ **Acumula automaticamente** taxas geradas por swaps
- ✅ **Reinveste fees** como liquidez quando condições são atendidas
- ✅ **Calcula dinamicamente** thresholds baseado em custo de gas
- ✅ **Suporta múltiplas pools** simultaneamente
- ✅ **Automação via Keeper** para execução periódica

### **Benefícios**

- 🚀 **Maximiza retornos** através de compound automático
- 💰 **Economiza gas** verificando rentabilidade antes de executar
- 🔒 **Seguro** com verificações de acesso e proteções contra overflow
- ⚙️ **Configurável** por pool (preços, tick range, enabled/disabled)

---

## ✨ **Features Principais**

### **1. Acumulação Automática de Fees**
- Fees são acumuladas automaticamente durante cada swap
- Suporte para ambos os tokens (token0 e token1)
- Rastreamento separado por pool

### **2. Compound Inteligente**
O compound é executado automaticamente quando:
- ⏰ Passaram **4 horas** desde o último compound
- 💵 Fees acumuladas valem **≥ 20x o custo de gas** em USD
- ✅ Pool está habilitada
- 📊 Tick range está configurado

### **3. Cálculo Dinâmico de Threshold**
- Threshold calculado automaticamente baseado em:
  - Custo atual de gas (block.basefee)
  - Preços dos tokens em USD (configuráveis)
- Não requer configuração manual de valores fixos

### **4. Sistema de Keeper**
- Script automatizado para execução periódica
- Verifica condições antes de executar (economiza gas)
- Pode ser configurado via cron ou systemd

---

## 🏗️ **Arquitetura**

```
┌──────────────┐
│ PoolManager  │ (Uniswap V4)
└──────┬───────┘
       │
       │ callbacks
       │
┌──────▼──────────────┐
│ AutoCompoundHook    │
│  - Acumula fees     │
│  - Verifica cond.   │
│  - Prepara compound │
└──────┬──────────────┘
       │
       │ prepareCompound()
       │
┌──────▼──────────────┐
│ CompoundHelper      │
│  - Executa compound │
│  - Gerencia unlock  │
└──────┬──────────────┘
       │
       │ unlock()
       │
┌──────▼──────────────┐
│ PoolManager         │
│  - Adiciona liquidez│
└─────────────────────┘
```

**📚 Documentação completa**: Veja [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## 🚀 **Quick Start**

### **1. Pré-requisitos**

- [Foundry](https://book.getfoundry.sh/getting-started/installation) instalado
- Node.js (opcional, para scripts)
- Carteira com ETH para deploy

### **2. Instalação**

```bash
# Clone o repositório
git clone https://github.com/DRHenney/amebacrypto.git
cd amebacrypto

# Instale dependências
forge install

# Compile
forge build
```

### **3. Configuração**

Crie um arquivo `.env`:

```bash
PRIVATE_KEY=sua_chave_privada
POOL_MANAGER=endereco_do_poolmanager
HOOK_ADDRESS=endereco_do_hook
TOKEN0_ADDRESS=endereco_token0
TOKEN1_ADDRESS=endereco_token1
SEPOLIA_RPC_URL=https://rpc.sepolia.org
```

### **4. Deploy**

```bash
# Deploy do hook
bash deploy-hook.sh

# Criar pool
bash criar-pool-full-range-atualizada.sh

# Adicionar liquidez
bash adicionar-liquidez-full-range-atualizada.sh
```

**📚 Guia completo**: Veja [GUIA-DEPLOY-TESTNET.md](./GUIA-DEPLOY-TESTNET.md)

---

## 📚 **Documentação**

### **Documentação Principal**
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Arquitetura e design do sistema
- **[HOOK-AUTO-COMPOUND.md](./HOOK-AUTO-COMPOUND.md)** - Documentação completa do hook
- **[README-KEEPER.md](./README-KEEPER.md)** - Guia do sistema de keeper
- **[README-TESTES.md](./README-TESTES.md)** - Documentação dos testes

### **Guias Práticos**
- **[GUIA-DEPLOY-TESTNET.md](./GUIA-DEPLOY-TESTNET.md)** - Guia completo de deploy
- **[GUIA-EXECUTAR-SCRIPTS.md](./GUIA-EXECUTAR-SCRIPTS.md)** - Como executar scripts

### **Referências**
- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [v4-by-example](https://v4-by-example.org)

---

## 🧪 **Testes**

### **Executar Todos os Testes**

```bash
bash executar-testes.sh
```

Ou manualmente:

```bash
forge test --via-ir -vvv
```

### **Cobertura de Testes**

- ✅ **39/41 testes passando** (95.1% de sucesso)
- ✅ **14 testes abrangentes** no `AutoCompoundHookComprehensiveTest`
- ✅ **23 testes básicos** no `AutoCompoundHookTest`

**📚 Documentação**: Veja [README-TESTES.md](./README-TESTES.md)

---

## 🔧 **Desenvolvimento**

### **Compilar**

```bash
forge build --via-ir
```

### **Testar**

```bash
forge test --via-ir -vvv
```

### **Formatar**

```bash
forge fmt
```

### **Lint**

```bash
forge lint
```

---

## 📊 **Status do Projeto**

- ✅ **Hook funcional** e testado
- ✅ **Compound automático** implementado
- ✅ **Keeper configurado** e funcionando
- ✅ **Testes automatizados** (95% de sucesso)
- ✅ **Documentação** em desenvolvimento

**📋 Avaliação completa**: Veja [AVALIACAO-PROJETO-COMPLETA.md](./AVALIACAO-PROJETO-COMPLETA.md)

---

## 🤝 **Contribuindo**

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

---

## 📄 **Licença**

Este projeto está sob a licença MIT. Veja [LICENSE](./LICENSE) para mais detalhes.

---

## 🔗 **Links Úteis**

- [Uniswap V4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [v4-by-example](https://v4-by-example.org)
- [GitHub Repository](https://github.com/DRHenney/amebacrypto)

---

**Desenvolvido com ❤️ para a comunidade Uniswap V4**
