# Script Inteligente de Instalação do Foundry
# Tenta instalar via Windows primeiro, se não conseguir, orienta para WSL

Write-Host "=== Instalação do Foundry ===" -ForegroundColor Cyan
Write-Host ""

# Verificar se Build Tools está instalado
$vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
$buildToolsInstalado = Test-Path $vsPath

if ($buildToolsInstalado) {
    Write-Host "✓ Visual Studio Build Tools encontrado!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Instalando Foundry via Cargo..." -ForegroundColor Yellow
    Write-Host "Isso pode levar 15-30 minutos na primeira vez..." -ForegroundColor Cyan
    Write-Host ""
    
    cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=== ✓ Foundry Instalado com Sucesso! ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "Feche e reabra o PowerShell, depois execute:" -ForegroundColor Yellow
        Write-Host "  cd C:\Users\derek\amebacrypto" -ForegroundColor White
        Write-Host "  forge --version" -ForegroundColor White
        Write-Host "  forge test" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "Erro na instalação. Use o WSL (mais fácil)." -ForegroundColor Yellow
        $buildToolsInstalado = $false
    }
} else {
    Write-Host "Visual Studio Build Tools não encontrado." -ForegroundColor Yellow
    Write-Host ""
    $buildToolsInstalado = $false
}

if (-not $buildToolsInstalado) {
    Write-Host "=== Usando WSL (Recomendado) ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Verificar se WSL está disponível
    $wslOk = $false
    try {
        $null = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $wslOk = $true
        }
    } catch {
        $wslOk = $false
    }
    
    if ($wslOk) {
        Write-Host "✓ WSL está disponível!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Instalando Foundry no WSL..." -ForegroundColor Yellow
        Write-Host ""
        
        # Tentar instalar via WSL
        wsl bash -c "curl -L https://foundry.paradigm.xyz | bash; foundryup"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "=== ✓ Foundry Instalado no WSL! ===" -ForegroundColor Green
            Write-Host ""
            Write-Host "Para usar o Foundry:" -ForegroundColor Yellow
            Write-Host "  wsl forge --version" -ForegroundColor White
            Write-Host "  wsl forge test" -ForegroundColor White
            Write-Host ""
            Write-Host "Ou entre no WSL:" -ForegroundColor Yellow
            Write-Host "  wsl" -ForegroundColor White
            Write-Host "  cd /mnt/c/Users/derek/amebacrypto" -ForegroundColor White
            Write-Host "  forge test" -ForegroundColor White
        } else {
            Write-Host ""
            Write-Host "Erro ao instalar no WSL. O WSL pode precisar de reinicialização." -ForegroundColor Red
            Write-Host ""
            Write-Host "Reinicie o Windows e depois execute:" -ForegroundColor Yellow
            Write-Host "  wsl" -ForegroundColor White
            Write-Host "  curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
            Write-Host "  foundryup" -ForegroundColor White
        }
    } else {
        Write-Host "WSL não está disponível ou precisa de reinicialização." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Reinicie o Windows e depois execute:" -ForegroundColor Cyan
        Write-Host "  wsl" -ForegroundColor White
        Write-Host "  curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
        Write-Host "  foundryup" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== Resumo ===" -ForegroundColor Cyan
Write-Host "Arquivos de ajuda criados:" -ForegroundColor Yellow
Write-Host "  - INICIO-RAPIDO.md (guia completo)" -ForegroundColor White
Write-Host "  - POS-REINICIAR.md (instruções para WSL)" -ForegroundColor White
Write-Host "  - INSTALACAO.md (guia detalhado)" -ForegroundColor White
