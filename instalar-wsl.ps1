Write-Host "=== Instalando Foundry via WSL ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Verificando WSL..." -ForegroundColor Yellow
$wslOk = $false

try {
    $result = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wslOk = $true
        Write-Host "WSL encontrado!" -ForegroundColor Green
    }
} catch {
    Write-Host "WSL nao disponivel. Reinicie o Windows primeiro." -ForegroundColor Red
    exit
}

if ($wslOk) {
    Write-Host ""
    Write-Host "Instalando Foundry no WSL..." -ForegroundColor Yellow
    Write-Host "Isso pode levar alguns minutos..." -ForegroundColor Cyan
    Write-Host ""
    
    wsl bash -c "curl -L https://foundry.paradigm.xyz | bash"
    wsl foundryup
    
    Write-Host ""
    Write-Host "=== Instalacao concluida! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Para usar:" -ForegroundColor Yellow
    Write-Host "  wsl forge --version" -ForegroundColor White
    Write-Host "  wsl forge test" -ForegroundColor White
}


