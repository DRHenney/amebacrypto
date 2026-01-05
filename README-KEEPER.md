# Auto Compound Keeper

Este keeper automatiza a execução do compound na pool quando as condições são atendidas.

## Como Funciona

O keeper verifica periodicamente se pode executar compound e, se as condições forem atendidas, executa automaticamente.

### Condições para Compound

1. Pool habilitada
2. 4 horas desde o último compound (ou nunca houve compound)
3. Fees acumuladas > 0
4. Fees value >= 20x gas cost (ou preços não configurados)
5. Tick range configurado
6. Liquidity delta > 0

## Execução Manual

Para executar o keeper manualmente:

```bash
bash executar-keeper-compound.sh
```

## Execução Automática (Cron)

Para executar o keeper automaticamente a cada hora, adicione ao crontab:

```bash
# Editar crontab
crontab -e

# Adicionar linha (executa a cada hora)
0 * * * * cd /mnt/c/Users/derek/amebacrypto && bash executar-keeper-compound.sh >> /tmp/compound-keeper.log 2>&1

# Ou executar a cada 30 minutos
*/30 * * * * cd /mnt/c/Users/derek/amebacrypto && bash executar-keeper-compound.sh >> /tmp/compound-keeper.log 2>&1
```

## Execução Automática (Systemd Timer)

Para usar systemd timer (mais robusto):

1. Criar arquivo de serviço: `/etc/systemd/system/compound-keeper.service`
2. Criar arquivo de timer: `/etc/systemd/system/compound-keeper.timer`

### compound-keeper.service

```ini
[Unit]
Description=Auto Compound Keeper
After=network.target

[Service]
Type=oneshot
User=derek
WorkingDirectory=/mnt/c/Users/derek/amebacrypto
ExecStart=/bin/bash /mnt/c/Users/derek/amebacrypto/executar-keeper-compound.sh
StandardOutput=journal
StandardError=journal
```

### compound-keeper.timer

```ini
[Unit]
Description=Run Auto Compound Keeper every hour
Requires=compound-keeper.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

Ativar o timer:

```bash
sudo systemctl enable compound-keeper.timer
sudo systemctl start compound-keeper.timer
sudo systemctl status compound-keeper.timer
```

## Logs

Os logs são salvos em:
- Crontab: `/tmp/compound-keeper.log`
- Systemd: `journalctl -u compound-keeper.service`

## Notas

- O keeper verifica as condições antes de executar
- Se as condições não forem atendidas, o keeper não executa (economiza gas)
- O compound só é executado quando todas as condições são atendidas
- O intervalo de 4 horas é verificado automaticamente pelo hook

