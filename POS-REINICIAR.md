# Instruções Após Reiniciar o Windows

O WSL foi configurado e precisa de uma reinicialização para funcionar completamente.

## Passo 1: Após Reiniciar

Abra o PowerShell ou Terminal e execute:

```bash
wsl
```

## Passo 2: Instalar o Foundry no WSL

Dentro do WSL (Ubuntu), execute:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Passo 3: Verificar Instalação

```bash
forge --version
cast --version
anvil --version
```

## Passo 4: Trabalhar no Projeto

Você pode trabalhar no projeto de duas formas:

### Opção A: Usar WSL diretamente

```bash
cd /mnt/c/Users/derek/amebacrypto
forge test
```

### Opção B: Usar PowerShell e chamar comandos WSL

No PowerShell:

```powershell
cd C:\Users\derek\amebacrypto
wsl forge test
```

## Alternativa: Instalar Visual Studio Build Tools

Se preferir não usar WSL, você pode instalar o Visual Studio Build Tools:

1. Execute como Administrador:
```powershell
winget install Microsoft.VisualStudio.2022.BuildTools --override '--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools'
```

2. Feche e reabra o PowerShell

3. Instale o Foundry:
```powershell
cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked
```

## Próximos Passos

Após instalar o Foundry:

1. Execute os testes:
   ```bash
   forge test
   ```

2. Desenvolva seu hook personalizado baseado em `src/Counter.sol`

3. Use os scripts de deploy em `script/` para testar localmente

