# Guia de Instalação - AmebaCrypto (Uniswap v4 Hook)

## Pré-requisitos

Este projeto requer o **Foundry** para compilar e testar os contratos Solidity.

### Instalando o Foundry no Windows

Existem duas opções principais:

#### Opção 1: Instalação via PowerShell (Recomendado)

1. Abra o PowerShell como Administrador
2. Execute o seguinte comando:

```powershell
irm https://github.com/foundry-rs/foundry/releases/latest/download/foundry_nightly_x86_64-pc-windows-msvc.zip -OutFile foundry.zip
Expand-Archive foundry.zip -DestinationPath $env:USERPROFILE\.foundry
$env:PATH += ";$env:USERPROFILE\.foundry\bin"
[Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::User)
```

3. Feche e reabra o PowerShell
4. Verifique a instalação:

```powershell
forge --version
cast --version
anvil --version
```

#### Opção 2: Instalação via WSL (Windows Subsystem for Linux)

1. Instale o WSL2 seguindo o [guia oficial da Microsoft](https://learn.microsoft.com/pt-br/windows/wsl/install)
2. Abra o terminal WSL
3. Execute:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

4. Verifique a instalação:

```bash
forge --version
```

## Configuração do Projeto

### 1. Dependências já instaladas ✅

Os submódulos Git já foram instalados:
- `forge-std` - Biblioteca padrão do Foundry
- `uniswap-hooks` - Biblioteca de hooks do Uniswap v4
- `hookmate` - Ferramentas auxiliares para hooks

### 2. Instalar dependências do Foundry

Após instalar o Foundry, execute:

```bash
cd C:\Users\derek\amebacrypto
forge install
```

### 3. Executar testes

```bash
forge test
```

## Estrutura do Projeto

- `src/Counter.sol` - Hook de exemplo que demonstra `beforeSwap()` e `afterSwap()`
- `test/Counter.t.sol` - Testes para o hook Counter
- `script/` - Scripts de deploy e configuração

## Próximos Passos

1. **Instalar o Foundry** (se ainda não instalado)
2. **Executar os testes**: `forge test`
3. **Desenvolver seu hook personalizado** baseado no exemplo `Counter.sol`
4. **Deploy local** usando Anvil (veja README.md para mais detalhes)

## Recursos Adicionais

- [Documentação do Uniswap v4](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [v4-by-example](https://v4-by-example.org)

