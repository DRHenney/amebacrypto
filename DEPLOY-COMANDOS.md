# 📋 Comandos para Deploy - Passo a Passo

## 🔄 Passo 1: Fazer Novo Deploy do Hook

Execute este comando no terminal WSL:

```bash
cd /mnt/c/Users/derek/amebacrypto

forge script script/DeployAutoCompoundHook.s.sol \
  --rpc-url https://ethereum-sepolia-rpc.publicnode.com \
  --broadcast \
  -vvvv
```

**⚠️ IMPORTANTE**: Este deploy vai criar um NOVO endereço (diferente do anterior) porque o hook foi modificado.

---

## 📍 Passo 2: Encontrar o Endereço no Output

Após o deploy completar, procure no terminal por uma destas linhas:

### Opção A:
```
=== Deploy Summary ===
Hook Address: 0x...[42 caracteres]
```

### Opção B:
```
✅  [Success] Hash: 0x...
Contract Address: 0x...[42 caracteres]
```

### Opção C:
```
AutoCompoundHook deployed at: 0x...[42 caracteres]
```

---

## 🔧 Passo 3: Atualizar o .env (Manual)

Após encontrar o endereço, você pode:

1. **Copiar o endereço** do terminal
2. **Me enviar aqui** e eu atualizo o `.env` para você

OU

**Atualizar manualmente** editando o arquivo `.env`:
- Procure a linha: `HOOK_ADDRESS=0xe9fc59e5A42ff793736357387bc961026b4C5540`
- Substitua pelo novo endereço

---

## 🤖 Passo 3 Alternativo: Atualizar Automaticamente

Depois do deploy, execute este comando para tentar extrair automaticamente:

```bash
bash extrair-endereco-hook.sh
```

Mas o mais garantido é procurar manualmente no output do terminal.

---

## ✅ Passo 4: Verificar

Após atualizar, verifique se está correto:

```bash
grep HOOK_ADDRESS .env
```

Deve mostrar: `HOOK_ADDRESS=0x...[novo endereço]`

---

## 🎯 Resumo

1. ✅ Execute o comando de deploy
2. ✅ Procure o endereço no output (linha "Hook Address:" ou "Contract Address:")
3. ✅ Me envie o endereço ou atualize o `.env` manualmente
4. ✅ Verifique que o Owner é sua carteira



