# Script para executar APÓS reiniciar o Windows
# Este script instala o Foundry no WSL

Write-Host "=== Instalando Foundry no WSL ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Verificando WSL..." -ForegroundColor Yellow
try {
    $wslVersion = wsl --version 2>&1
    Write-Host "WSL encontrado!" -ForegroundColor Green
} catch {
    Write-Host "WSL nao encontrado. Verifique se reiniciou o Windows." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "Instalando Foundry no WSL..." -ForegroundColor Yellow
Write-Host "Isso pode levar alguns minutos..." -ForegroundColor Cyan
Write-Host ""

# Instalar foundryup
Write-Host "Passo 1/2: Instalando foundryup..." -ForegroundColor Yellow
wsl bash -c "curl -L https://foundry.paradigm.xyz | bash"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ foundryup instalado!" -ForegroundColor Green
    Write-Host ""
    
    # Executar foundryup
    Write-Host "Passo 2/2: Instalando Foundry (forge, cast, anvil, chisel)..." -ForegroundColor Yellow
    wsl foundryup
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=== ✓ Foundry Instalado com Sucesso! ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "Verificando instalacao..." -ForegroundColor Yellow
        wsl forge --version
        Write-Host ""
        Write-Host "=== Como usar ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Opcao 1: Do PowerShell (recomendado):" -ForegroundColor Yellow
        Write-Host "  wsl forge test" -ForegroundColor White
        Write-Host "  wsl forge build" -ForegroundColor White
        Write-Host ""
        Write-Host "Opcao 2: Entrar no WSL:" -ForegroundColor Yellow
        Write-Host "  wsl" -ForegroundColor White
        Write-Host "  cd /mnt/c/Users/derek/amebacrypto" -ForegroundColor White
        Write-Host "  forge test" -ForegroundColor White
        Write-Host ""
        Write-Host "=== Teste rapido ===" -ForegroundColor Cyan
        Write-Host "Execute agora:" -ForegroundColor Yellow
        Write-Host "  wsl forge test" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Erro ao executar foundryup." -ForegroundColor Red
        Write-Host "Tente manualmente no WSL:" -ForegroundColor Yellow
        Write-Host "  wsl" -ForegroundColor White
        Write-Host "  foundryup" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "Erro ao instalar foundryup." -ForegroundColor Red
    Write-Host "Tente manualmente no WSL:" -ForegroundColor Yellow
    Write-Host "  wsl" -ForegroundColor White
    Write-Host "  curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
    Write-Host "  foundryup" -ForegroundColor White
}

Write-Host ""

