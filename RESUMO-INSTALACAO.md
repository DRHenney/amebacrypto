# 📋 Resumo da Instalação - AmebaCrypto

## ✅ O que já está pronto:

1. ✅ Repositório clonado em `C:\Users\derek\amebacrypto`
2. ✅ Todas as dependências Git instaladas (submódulos)
3. ✅ Rust e Cargo instalados
4. ✅ WSL configurado (mas precisa de distribuição Linux)

## 🎯 Próximo Passo: Instalar Foundry

Você tem **2 opções**:

---

### ⭐ Opção 1: WSL (RECOMENDADO - Mais Fácil)

**O WSL está configurado, mas precisa de uma distribuição Linux.**

#### Passo 1: Instalar Ubuntu no WSL
```powershell
wsl --install -d Ubuntu
```
*(Pode pedir para reiniciar - se pedir, reinicie e continue)*

#### Passo 2: Após reiniciar (se necessário), abra PowerShell e execute:
```bash
wsl
```

#### Passo 3: No WSL (Ubuntu), instale o Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

#### Passo 4: Verificar:
```bash
forge --version
cast --version
anvil --version
```

#### Trabalhar no projeto:
```bash
# No WSL:
cd /mnt/c/Users/derek/amebacrypto
forge test
```

**OU do PowerShell:**
```powershell
wsl forge test
wsl forge build
```

---

### 🔧 Opção 2: Windows Nativo (Mais Complexo)

**Requer Visual Studio Build Tools (já iniciado, mas pode levar 10-30 min)**

#### Passo 1: Aguardar Build Tools instalar
Verifique se terminou:
```powershell
Test-Path "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
```

#### Passo 2: Após Build Tools estar instalado:
```powershell
cd C:\Users\derek\amebacrypto
cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked
```
*(Isso pode levar 15-30 minutos)*

#### Passo 3: Feche e reabra o PowerShell, depois:
```powershell
forge --version
forge test
```

---

## 📁 Arquivos de Ajuda Criados:

- **`INICIO-RAPIDO.md`** - Guia completo com todas as opções
- **`POS-REINICIAR.md`** - Instruções detalhadas para WSL
- **`INSTALACAO.md`** - Guia detalhado original
- **`instalar-wsl.ps1`** - Script para instalar via WSL (após ter distribuição)
- **`setup-pos-buildtools.ps1`** - Script para instalar após Build Tools

---

## 🚀 Recomendação Final:

**Use o WSL (Opção 1)** - É mais simples, rápido e é o método recomendado pela comunidade Foundry para Windows.

1. Execute: `wsl --install -d Ubuntu`
2. Se pedir para reiniciar, reinicie
3. Abra PowerShell: `wsl`
4. No WSL: `curl -L https://foundry.paradigm.xyz | bash` e depois `foundryup`
5. Pronto! 🎉

---

## 📝 Após Instalar o Foundry:

```bash
# Testar instalação
forge --version
forge test

# Compilar contratos
forge build

# Executar testes
forge test -vvv
```

---

## 📚 Recursos:

- [Documentação Uniswap v4](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [v4-by-example](https://v4-by-example.org)

