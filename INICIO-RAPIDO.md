# Início Rápido - AmebaCrypto

## ✅ O que já está pronto:

1. ✅ Repositório clonado
2. ✅ Dependências Git instaladas
3. ✅ Rust instalado
4. ✅ WSL configurado (precisa reiniciar)

## 🚀 Instalar Foundry - Escolha uma opção:

### Opção 1: WSL (Recomendado - Mais Fácil) ⭐

**Após reiniciar o Windows:**

```bash
# 1. Abra PowerShell e execute:
wsl

# 2. No WSL, execute:
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 3. Verificar:
forge --version
```

**Trabalhar no projeto:**
```bash
# No WSL:
cd /mnt/c/Users/derek/amebacrypto
forge test
```

### Opção 2: Windows Nativo (Mais Rápido - Sem Reiniciar)

**Se o Visual Studio Build Tools foi instalado:**

1. Feche e reabra o PowerShell
2. Execute:
```powershell
cd C:\Users\derek\amebacrypto
.\setup-pos-buildtools.ps1
```

**Ou manualmente:**
```powershell
cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked
```

## 📝 Próximos Passos Após Instalar:

1. **Testar a instalação:**
   ```bash
   forge --version
   forge test
   ```

2. **Explorar o projeto:**
   - `src/Counter.sol` - Hook de exemplo
   - `test/Counter.t.sol` - Testes
   - `script/` - Scripts de deploy

3. **Desenvolver seu hook:**
   - Baseie-se no `Counter.sol`
   - Implemente sua lógica personalizada
   - Teste com `forge test`

## 📚 Recursos:

- [Documentação Uniswap v4](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [v4-by-example](https://v4-by-example.org)

## ⚡ Dica:

Se você reiniciou e está usando WSL, pode executar comandos Foundry diretamente do PowerShell:

```powershell
wsl forge test
wsl forge build
```

