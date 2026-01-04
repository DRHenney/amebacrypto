# AmebaCrypto - AutoCompound Hook para Uniswap v4

Hook para Uniswap v4 que automaticamente reinveste taxas acumuladas de volta na pool de liquidez.

## 📚 Documentação

- **[HOOK-AUTO-COMPOUND.md](./HOOK-AUTO-COMPOUND.md)**: Documentação completa do hook
- **[Foundry Book](https://book.getfoundry.sh/)**: Documentação do Foundry

## 🚀 Uso

### Compilar

```shell
forge build
```

### Testar

```shell
forge test
```

### Formatar

```shell
forge fmt
```

### Deploy

**Guia Completo**: Veja [GUIA-DEPLOY-TESTNET.md](./GUIA-DEPLOY-TESTNET.md) para instruções detalhadas.

**Deploy Rápido**:

```shell
# 1. Configure as variáveis de ambiente (.env)
PRIVATE_KEY=sua_chave_privada
POOL_MANAGER=endereco_do_poolmanager
SEPOLIA_RPC_URL=https://rpc.sepolia.org

# 2. Deploy do hook
forge script script/DeployAutoCompoundHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# 3. Configure o hook após deploy
forge script script/ConfigureHook.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## 🔧 Funcionalidades do Hook

- **Acumulação automática de taxas** durante swaps
- **Compound automático** quando:
  - Passaram 4 horas desde o último compound
  - Taxas acumuladas valem >= 20x o custo de gas em USD
- **Cálculo automático de threshold** baseado no custo atual de gas
- **Suporte para múltiplas pools** simultaneamente

Veja [HOOK-AUTO-COMPOUND.md](./HOOK-AUTO-COMPOUND.md) para mais detalhes.

## 📖 Recursos

- [Documentação Uniswap v4](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [v4-by-example](https://v4-by-example.org)
