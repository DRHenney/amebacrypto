# ⏰ Como Verificar Tempo até Próximo Compound

**Data**: 2025-01-27

---

## 🚀 Forma Mais Rápida

Execute o script simples:

```bash
bash verificar-tempo-compound.sh
```

Este script mostra:
- ✅ Se pode executar compound agora
- ⏰ Tempo restante (horas, minutos, segundos)
- 📊 Último compound executado
- 💰 Informações econômicas (fees, gas cost)

---

## 📋 O que o Script Mostra

### 1. Status Atual
- **Pode Executar Compound**: `true` ou `false`
- **Motivo** (se não puder executar)

### 2. Tempo Restante
- Tempo em segundos, horas, minutos
- Formato legível
- Se for 0, pode executar agora!

### 3. Último Compound
- Timestamp do último compound
- Tempo desde o último compound
- Se nunca executou, mostra "Nenhum compound executado ainda"

### 4. Informações Econômicas
- Valor das fees em USD
- Custo de gas em USD
- Multiplicador (fees/gas)

---

## 🔍 Forma Alternativa (Mais Detalhada)

Para ver informações completas do hook:

```bash
bash verificar-estado-hook.sh
```

Este script mostra:
- ✅ Tudo do script acima
- 📊 Configurações da pool
- 💰 Fees acumuladas
- 🏊 Estado da pool
- 📈 Muitas outras informações

---

## 💡 Entendendo o Intervalo

O hook tem um **intervalo mínimo de 4 horas** entre compounds:

- **COMPOUND_INTERVAL**: 4 horas (14,400 segundos)
- Se executou compound agora, precisa esperar 4 horas para o próximo
- Se nunca executou, pode executar imediatamente

---

## 📝 Exemplo de Saída

```
=== Tempo Ate Proximo Compound ===
Pool ID: 28256298611757681241013306313511050759847663993524451406477851312375608566082

=== Status Atual ===
Pode Executar Compound: true

=== Tempo Restante ===
PODE EXECUTAR AGORA! (0 segundos restantes)

=== Ultimo Compound ===
Nenhum compound executado ainda

=== Informacoes Economicas ===
Fees Value (USD): 54000000000000000
Gas Cost (USD): 0
```

---

## 🎯 Resumo

**Para verificar tempo até próximo compound:**

```bash
bash verificar-tempo-compound.sh
```

**Simples, rápido e direto!** ⚡

---

**Criado para facilitar o monitoramento do hook!** ✅


