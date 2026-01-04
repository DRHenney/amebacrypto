# 📍 Como Encontrar o Endereço do Hook no Output

## 🔍 Onde procurar no output do comando `forge script`:

### Opção 1: Na seção "== Logs =="
Procure por:
```
== Logs ==
  ...
  Hook Address: 0xe9fc59e5A42ff793736357387bc961026b4C5540
```

### Opção 2: Na seção "=== Deploy Summary ==="
Procure por:
```
=== Deploy Summary ===
Hook Address: 0xe9fc59e5A42ff793736357387bc961026b4C5540
```

### Opção 3: Na linha de sucesso
Procure por:
```
✅  [Success] Hash: 0x...
Contract Address: 0xe9fc59e5A42ff793736357387bc961026b4C5540
```

### Opção 4: Na linha "AutoCompoundHook deployed at:"
Procure por:
```
AutoCompoundHook deployed at: 0xe9fc59e5A42ff793736357387bc961026b4C5540
```

---

## 🚀 Método Automático

Execute este script para extrair automaticamente:

```bash
bash extrair-endereco-hook.sh
```

---

## 📝 Exemplo de Output Completo

Quando o deploy for bem-sucedido, você verá algo assim:

```
== Logs ==
  Deploying AutoCompoundHook...
  PoolManager: 0xc77aE1faE9BB15fDD1Ea96897A12Ec074FA65250
  Hook address found: 0x...[NOVO_ENDERECO]
  AutoCompoundHook deployed at: 0x...[NOVO_ENDERECO]
  Owner: 0x63f976191f9Dd75bd5b0fD81320D37FBC0d74080

=== Deploy Summary ===
Hook Address: 0x...[NOVO_ENDERECO]  <-- ESTE É O ENDEREÇO!

##### sepolia
✅  [Success] Hash: 0x...
Contract Address: 0x...[NOVO_ENDERECO]  <-- OU ESTE!
```

---

## 💡 Dica

O endereço sempre começa com `0x` e tem 42 caracteres no total (incluindo `0x`).

Exemplo: `0xe9fc59e5A42ff793736357387bc961026b4C5540`



